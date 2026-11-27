import Foundation
import NimbraCore
import Testing
@testable import Nimbra

/// Mailboxes, All inboxes, labels, blocking and search on the fake engine: no network.
@MainActor
struct MailboxesTests {
    private func app(_ engine: FakeEngine) async -> AppModel {
        let app = Fixture.app(engine)
        await app.start()
        return app
    }

    // MARK: Counts

    @Test func mailboxRowsCountAsTheMacDoes() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.state.withLock { state in
            state.counts["g1"] = [
                LabelCount(labelId: "INBOX", unread: 3, total: 40),
                LabelCount(labelId: "IMPORTANT", unread: 4, total: 9),
                LabelCount(labelId: "DRAFT", unread: 0, total: 2),
                LabelCount(labelId: "L1", unread: 1, total: 5),
            ]
            state.snoozed["g1"] = [
                SnoozedThread(threadId: "s1", accountId: "g1", untilMs: 1, onlyIfNoReply: false, subject: "", sender: "", snippet: ""),
                SnoozedThread(threadId: "r1", accountId: "g1", untilMs: 2, onlyIfNoReply: true, subject: "", sender: "", snippet: ""),
                SnoozedThread(threadId: "r2", accountId: "g1", untilMs: 3, onlyIfNoReply: true, subject: "", sender: "", snippet: ""),
            ]
        }
        let app = await app(engine)
        await app.showMailboxes("g1")

        #expect(app.count(.inbox, in: "g1") == 3)
        #expect(app.count(.important, in: "g1") == 4)
        // Drafts counts all of them, not the unread.
        #expect(app.count(.drafts, in: "g1") == 2)
        #expect(app.count(.label(id: "L1"), in: "g1") == 1)
        #expect(app.count(.snoozed, in: "g1") == 1)
        #expect(app.count(.reminders, in: "g1") == 2)
        // Sent and Starred show no count.
        #expect(app.count(.sent, in: "g1") == 0)
        #expect(app.count(.starred, in: "g1") == 0)
        #expect(app.wakeTime(MailThread.ID(account: "g1", thread: "r1")) == Date(milliseconds: 2))
    }

    @Test func sectionsFollowTheEnginesOrder() async {
        let app = await app(FakeEngine(accounts: [Fixture.gmail]))
        #expect(app.mailboxes("g1", in: .split).map(\.mailbox) == [.inbox] + SplitCategory.allCases.map(\.mailbox))
        #expect(app.mailboxes("g1", in: .mailboxes).map(\.mailbox) == [.starred])
        #expect(app.labels("g1").map(\.name) == ["Travel"])
    }

    // MARK: Labels

    @Test func createsALabelOnceAndNeverABlankOne() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let app = await app(engine)

        let made = await app.createLabel("  Receipts ", in: "g1")
        #expect(made?.name == "Receipts")
        #expect(app.labels("g1").map(\.name) == ["Travel", "Receipts"])

        // Already there, in any case: that one, and nothing asked of the server.
        let known = await app.createLabel("travel", in: "g1")
        #expect(known?.id == "L1")
        #expect(await app.createLabel("   ", in: "g1") == nil)
        #expect(engine.calls.filter { $0.hasPrefix("createLabel") } == ["createLabel Receipts"])
    }

    @Test func renamingAndDeletingALabelFollowsItsThreads() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let travel = ListingKey(account: "g1", mailbox: .label(id: "L1"))
        engine.state.withLock { $0.cached[travel] = [Fixture.row("t1", labels: ["L1"])] }
        let app = await app(engine)
        await app.show(travel)
        let label = try! #require(app.labels("g1").first)

        await app.renameLabel(label, to: "Trips", in: "g1")
        #expect(app.labels("g1").map(\.name) == ["Trips"])
        #expect(app.listings[travel]?.threads.first?.labels == ["Trips"])

        engine.fail("deleteLabel", with: .NotFound)
        await app.deleteLabel(app.labels("g1")[0], in: "g1")
        // Already gone counts as deleted: the list and the threads forget it.
        #expect(app.alert == nil)
        #expect(app.listings[travel] == nil)
    }

    @Test func togglesALabelAndPutsItBackWhenRefused() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        let inbox = ListingKey(account: "i1", mailbox: .inbox)
        engine.state.withLock { $0.cached[inbox] = [Fixture.row("t1")] }
        let app = await app(engine)
        let id = MailThread.ID(account: "i1", thread: "t1")
        let travel = app.labels("i1")[0]

        await app.toggleLabel(travel, on: id)
        #expect(app.labelIDs(of: id) == ["L1"])
        #expect(engine.calls.contains("relabel t1 +[\"L1\"] -[]"))

        await app.toggleLabel(travel, on: id)
        #expect(app.labelIDs(of: id).isEmpty)

        engine.fail("relabel", with: .Offline)
        await app.toggleLabel(travel, on: id)
        #expect(app.labelIDs(of: id).isEmpty)
    }

    @Test func movingToALabelFromTheInboxTakesItOut() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        let inbox = ListingKey(account: "i1", mailbox: .inbox)
        engine.state.withLock { $0.cached[inbox] = [Fixture.row("t1"), Fixture.row("t2")] }
        let app = await app(engine)

        await app.move(MailThread.ID(account: "i1", thread: "t1"), to: app.labels("i1")[0])
        #expect(app.inboxThreads.map(\.id.thread) == ["t2"])
        #expect(engine.calls.contains("moveToLabel t1 L1 inbox"))
    }

    // MARK: All inboxes

    @Test func allInboxesMergesEveryAccountNewestFirst() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, Fixture.imap])
        var older = Fixture.row("a", at: 1_700_000_000, labels: ["INBOX", "L1"])
        older.accountId = "i1"
        var newer = Fixture.row("b", unread: true, at: 1_800_000_000)
        newer.accountId = "g1"
        engine.state.withLock { $0.allInboxes = [newer, older] }
        let app = await app(engine)

        await app.showAllInboxes()
        let threads = app.allInboxesListing?.threads ?? []
        #expect(threads.map(\.id) == [MailThread.ID(account: "g1", thread: "b"), MailThread.ID(account: "i1", thread: "a")])
        // Each row names its own account's labels, and carries its account for the tag.
        #expect(threads.last?.labels == ["Travel"])
        #expect(app.account(threads[0].id.account)?.email == "ana@gmail.com")
        #expect(app.inboxUnread("g1") == 1)
        #expect(app.allInboxesListing?.isFresh == true)
        #expect(engine.calls.contains("allInboxes 30"))

        // Done from All inboxes takes it out there too.
        await app.markDone(threads[0].id)
        #expect(app.allInboxesListing?.threads.map(\.id.thread) == ["a"])
    }

    // MARK: Blocking

    @Test func blocksTheSenderAndUndoPutsItBack() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let primary = ListingKey(account: "g1", mailbox: .split(category: .primary))
        engine.state.withLock { $0.cached[primary] = [Fixture.row("t1"), Fixture.row("t2")] }
        let app = await app(engine)
        let id = MailThread.ID(account: "g1", thread: "t1")

        await app.blockSender(of: id)
        #expect(app.inboxThreads.map(\.id.thread) == ["t2"])
        #expect(engine.calls.contains("block ana@example.com t1 inbox"))
        #expect(app.blockedSenders["g1"] == ["ana@example.com"])

        // The toast's Undo.
        await app.undoBlock("ana@example.com", of: id)
        #expect(engine.calls.contains("unblock ana@example.com t1"))
        #expect(app.blockedSenders["g1"] == [])
    }

    @Test func aRefusedBlockLeavesTheThreadWhereItWas() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("t1")] }
        let app = await app(engine)
        engine.fail("blockSender", with: .Failed(message: "No."))

        await app.blockSender(of: MailThread.ID(account: "i1", thread: "t1"))
        #expect(app.inboxThreads.map(\.id.thread) == ["t1"])
        #expect(app.alert == .failed("No."))
    }

    @Test func unblocksFromTheList() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.blocked["i1"] = ["spam@example.com", "deals@example.com"] }
        let app = await app(engine)
        await app.loadAllBlocked()
        #expect(app.blockedSenders["i1"] == ["deals@example.com", "spam@example.com"])

        await app.unblock("spam@example.com", in: "i1")
        #expect(app.blockedSenders["i1"] == ["deals@example.com"])
        #expect(engine.calls.contains("unblock spam@example.com -"))
    }

    // MARK: Search

    @Test func searchShowsTheDevicesMatchesThenTheServers() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("t1"), Fixture.row("t2")] }
        let app = await app(engine)

        #expect(app.localMatches("subject t2", in: "i1").map(\.id.thread) == ["t2"])
        // Search words with a colon are the server's.
        #expect(app.localMatches("is:unread", in: "i1").isEmpty)

        await app.find("Subject t1")
        #expect(app.searchResults.map(\.id.thread) == ["t1"])
        #expect(engine.calls.contains("search Subject t1"))

        await app.find("")
        #expect(app.searchResults.isEmpty)
    }

    // MARK: Groups

    @Test func listsGroupAsTheFramesDo() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        // Thursday, November 26, 2026, 9:41.
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 9, minute: 41)))
        func thread(_ id: String, days: Int) -> Nimbra.MailThread {
            Nimbra.MailThread(id: .init(account: "a", thread: id), subject: "", sender: nil, snippet: "",
                       date: calendar.date(byAdding: .day, value: days, to: now)!, messageCount: 1)
        }
        let past = ThreadGroup.group([thread("today", days: 0), thread("tue", days: -2), thread("nov3", days: -23), thread("oct", days: -40)],
                                     as: .past, date: \.date, now: now, calendar: calendar)
        #expect(past.map(\.id) == ["THIS WEEK", "THIS MONTH", "EARLIER"])
        #expect(past[0].threads.map(\.id.thread) == ["today", "tue"])

        let upcoming = ThreadGroup.group([thread("fri", days: 1), thread("mon", days: 4), thread("later", days: 20)],
                                         as: .upcoming, date: \.date, now: now, calendar: calendar)
        #expect(upcoming.map(\.id) == ["TOMORROW", "NEXT WEEK", "LATER"])
    }
}
