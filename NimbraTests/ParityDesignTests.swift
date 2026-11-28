import Foundation
import NimbraCore
import Testing
@testable import Nimbra

/// The parity designs on core 0.1.8: the Unread filter, reply-all keeping Cc and Bcc, the
/// new preferences, the accounts' order and photos, every account's mailboxes, the mail
/// text size, folding a thread and clearing the mail kept on the device. No network.
@MainActor
struct ParityDesignTests {
    private let second = NimbraCore.Account(id: "g2", email: "ben@gmail.com", kind: .gmail, isDefault: false)

    // MARK: Inbox · Unread

    @Test func theUnreadFilterListsOnlyUnreadThreads() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock {
            $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [
                Fixture.row("a", unread: true), Fixture.row("b"), Fixture.row("c", unread: true),
            ]
        }
        let app = Fixture.app(engine)
        await app.start()
        #expect(InboxFilter.all.apply(app.inboxThreads).map(\.id.thread) == ["a", "b", "c"])
        #expect(InboxFilter.unread.apply(app.inboxThreads).map(\.id.thread) == ["a", "c"])
        #expect(app.inboxFilter == .all)
    }

    // MARK: Compose · reply-all

    @Test func replyAllKeepsCcAndBccInTheComposer() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.state.withLock {
            $0.start = DraftStart(
                subject: "Re: Q4", to: ["ana@example.com"], cc: ["carla@example.com"], bcc: ["ben@example.com"],
                quoted: nil, kept: [], reply: ReplyRef(threadId: "t1", messageId: "<m1@x>"), signature: nil
            )
        }
        let app = Fixture.app(engine)
        await app.start()
        await app.startAnswer(.replyAll, to: Nimbra.MailThread.ID(account: "g1", thread: "t1"))
        let composer = try! #require(app.composer)
        #expect(composer.to == ["ana@example.com"])
        #expect(composer.cc == ["carla@example.com"])
        #expect(composer.bcc == ["ben@example.com"])
        #expect(composer.showsCcBcc)
        #expect(composer.outgoing.cc == "carla@example.com")
        #expect(composer.outgoing.bcc == "ben@example.com")
    }

    @Test func aReplyWithoutCcKeepsTheFieldsFolded() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.state.withLock {
            $0.start = DraftStart(subject: "Re: Q4", to: ["ana@example.com"], cc: [], bcc: [], quoted: nil, kept: [], reply: nil, signature: nil)
        }
        let app = Fixture.app(engine)
        await app.start()
        await app.startAnswer(.reply, to: Nimbra.MailThread.ID(account: "g1", thread: "t1"))
        let composer = try! #require(app.composer)
        #expect(composer.cc.isEmpty && composer.bcc.isEmpty)
        #expect(!composer.showsCcBcc)
    }

    @Test func theSampleEngineAnswersReplyAllAsTheEngineDoes() throws {
        let engine = SampleEngine()
        let start = try engine.startAnswer(accountId: SampleData.work.id, threadId: "launch", kind: .replyAll, dateText: "")
        #expect(start.to == [SampleData.mira.email, SampleData.jonah.email])
        #expect(start.cc == [SampleData.ana.email])
        #expect(start.bcc.isEmpty)
        let one = try engine.startAnswer(accountId: SampleData.work.id, threadId: "launch", kind: .reply, dateText: "")
        #expect(one.cc.isEmpty && one.bcc.isEmpty)
    }

    // MARK: Settings · Appearance

    @Test func theNewPreferencesAreKeptByTheEngineAndReadBack() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let app = Fixture.app(engine)
        await app.start()
        await app.setPreference(\.newestFirst, true)
        await app.setPreference(\.subjectOwnLine, false)
        await app.setPreference(\.textSize, .extraLarge)
        let kept = engine.preferences()
        #expect(kept.newestFirst && !kept.subjectOwnLine && kept.textSize == .extraLarge)

        let again = Fixture.app(engine)
        await again.start()
        await again.loadPreferences()
        #expect(again.preferences == kept)
    }

    @Test func aRefusedPreferenceIsPutBack() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let app = Fixture.app(engine)
        await app.start()
        engine.fail("setPreferences", with: .Failed(message: "Disk full"))
        await app.setPreference(\.textSize, .small)
        #expect(app.preferences.textSize == .default)
        #expect(app.alert != nil)
    }

    @Test func theMailTextSizeScalesTheMailOnly() {
        #expect(TextSize.default.scale == 1)
        #expect(TextSize.small.scale < 1)
        #expect(TextSize.allCases.map(\.scale) == TextSize.allCases.map(\.scale).sorted())
        // 17 pt reading text at the Mac's steps around its 15.
        #expect(abs(17 * TextSize.extraLarge.scale - 21.53) < 0.01)
        // The mail view: nothing added at the default, a percentage otherwise.
        #expect(MailDocument.textSize(1).isEmpty)
        #expect(MailDocument.textSize(TextSize.large.scale).contains("-webkit-text-size-adjust:113%"))
        #expect(MailDocument.html("<p>Hi</p>", images: false, textScale: TextSize.small.scale).contains("text-size-adjust:90%"))
    }

    // MARK: Thread · folding

    @Test func messagesShowOldestFirstOrNewestFirstAndTheLatestFolds() {
        let messages = ["a", "b", "c"].map { Message(id: $0, from: SampleData.mira, to: [], date: .now, body: "") }
        #expect(Folding.ordered(messages, newestFirst: false).map(\.id) == ["a", "b", "c"])
        #expect(Folding.ordered(messages, newestFirst: true).map(\.id) == ["c", "b", "a"])
        #expect(Folding.open(messages, expanded: [], latestFolded: false) == ["c"])
        #expect(Folding.open(messages, expanded: ["a"], latestFolded: true) == ["a"])
        // Folded, the latest joins the earlier ones in one card.
        let open = Folding.open(messages, expanded: [], latestFolded: true)
        #expect(Folding.runs(messages, expanded: open).map { $0.map(\.id) } == [["a", "b", "c"]])
        // Newest first, the latest opens above the card of the others.
        let shown = Folding.ordered(messages, newestFirst: true)
        #expect(Folding.runs(shown, expanded: Folding.open(messages, expanded: [], latestFolded: false)).map { $0.map(\.id) } == [["c"], ["b", "a"]])
    }

    @Test func aMessageKeepsCcBccAndReplyToApartFromTo() {
        let person = { (address: String) in NimbraCore.Person(name: "", address: address) }
        let message = Message(MailMessage(
            from: person("mira@example.com"), to: [person("luan@example.com")], cc: [person("ana@example.com")],
            bcc: [person("ben@example.com")], replyTo: person("launch@example.com"),
            sender: "Mira", address: "mira@example.com", others: [], messageId: "<m@x>", timestampMs: 0,
            snippet: "", blocks: [], text: "", html: nil, attachments: [], unsubscribe: nil
        ))
        #expect(message.to.map(\.email) == ["luan@example.com"])
        #expect(message.cc.map(\.email) == ["ana@example.com"])
        #expect(message.bcc.map(\.email) == ["ben@example.com"])
        #expect(message.replyTo?.email == "launch@example.com")
        #expect(message.recipients.map(\.email) == ["luan@example.com", "ana@example.com"])
    }

    // MARK: Mailboxes · accounts

    @Test func accountsMoveAsTheListHandsThemOver() async {
        let third = NimbraCore.Account(id: "i1", email: "ana@example.org", kind: .imap, isDefault: false)
        let engine = FakeEngine(accounts: [Fixture.gmail, second, third])
        let app = Fixture.app(engine)
        await app.start()
        // The last to the top: before the first.
        await app.moveAccounts(from: [2], to: 0)
        #expect(engine.calls.contains("moveAccount i1 0"))
        #expect(app.accounts.map(\.id) == ["i1", "g1", "g2"])
        // The first past the second: its place after the move is 1.
        await app.moveAccounts(from: [0], to: 2)
        #expect(engine.calls.contains("moveAccount i1 1"))
        #expect(app.accounts.map(\.id) == ["g1", "i1", "g2"])
        // Dropped where it was: nothing to keep.
        let before = engine.calls.count
        await app.moveAccounts(from: [1], to: 2)
        #expect(engine.calls.count == before)
    }

    @Test func aRefusedMoveShowsTheEnginesOrder() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, second])
        let app = Fixture.app(engine)
        await app.start()
        engine.fail("moveAccount", with: .Failed(message: "Disk full"))
        await app.moveAccounts(from: [1], to: 0)
        #expect(app.accounts.map(\.id) == ["g1", "g2"])
        #expect(app.alert != nil)
    }

    @Test func photosShowAsKeptThenAsTheProviderHasThem() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, second])
        engine.state.withLock {
            $0.keptPhotos["g1"] = Data([1])
            $0.photos["g1"] = .image(bytes: Data([2]))
            $0.keptPhotos["g2"] = Data([3])
            $0.photos["g2"] = .notAllowed
        }
        let app = Fixture.app(engine)
        await app.start()
        await app.loadAccountPhotos()
        #expect(app.accountPhotos["g1"] == Data([2]))
        // Not allowed to see the profile: the kept one stays.
        #expect(app.accountPhotos["g2"] == Data([3]))
        // Asked once a run.
        await app.loadAccountPhotos()
        #expect(engine.calls.filter { $0.hasPrefix("accountPhoto") }.count == 2)
    }

    // MARK: Mailboxes · every account

    @Test func everyAccountsMailboxListsEachRowInItsAccount() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, second])
        engine.state.withLock { state in
            var mine = Fixture.row("s1", at: 2)
            mine.accountId = "g1"
            var theirs = Fixture.row("s2", at: 1)
            theirs.accountId = "g2"
            state.every[.starred] = [mine, theirs]
        }
        let app = Fixture.app(engine)
        await app.start()
        let key = ListingKey.every(.starred)
        #expect(key.isEveryAccount && !ListingKey(account: "g1", mailbox: .starred).isEveryAccount)
        #expect(ListingKey.allInboxes == .every(.inbox))
        await app.showListing(key)
        #expect(engine.calls.contains("everyMailbox starred 30"))
        let threads = app.listings[key]?.threads ?? []
        #expect(threads.map(\.id) == [.init(account: "g1", thread: "s1"), .init(account: "g2", thread: "s2")])
        #expect(app.listings[key]?.isFresh == true)
        // A thread changed in its account changes in the merged list too.
        app.update(.init(account: "g2", thread: "s2")) { $0.isStarred = true }
        #expect(app.listings[key]?.threads.last?.isStarred == true)
    }

    @Test func everyAccountsMailboxesAndTheirCounts() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, second])
        engine.state.withLock {
            $0.counts["g1"] = [LabelCount(labelId: "DRAFT", unread: 0, total: 2)]
            $0.counts["g2"] = [LabelCount(labelId: "DRAFT", unread: 0, total: 3)]
        }
        let app = Fixture.app(engine)
        await app.start()
        #expect(app.everyAccountMailboxes == [.starred, .important, .snoozed, .reminders, .drafts, .sent, .spam, .trash])
        #expect(app.everyCount(.drafts) == 5)
        #expect(!app.showsEveryAccount)
    }

    @Test func withoutGmailEveryAccountHasNoImportant() async {
        let other = NimbraCore.Account(id: "i2", email: "ben@example.org", kind: .imap, isDefault: false)
        let app = Fixture.app(FakeEngine(accounts: [Fixture.imap, other]))
        await app.start()
        #expect(!app.everyAccountMailboxes.contains(.important))
    }

    // MARK: Settings · Privacy

    @Test func clearingKeptMailEmptiesWhatTheAppShowsAndListsAgain() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("a")] }
        let app = Fixture.app(engine)
        await app.start()
        app.blockedSenders["i1"] = ["spam@example.com"]
        app.accountPhotos["i1"] = Data([1])
        #expect(!app.inboxThreads.isEmpty)
        await app.clearKeptMail()
        #expect(engine.state.withLock { $0.cleared })
        #expect(app.blockedSenders.isEmpty)
        #expect(app.accountPhotos.isEmpty)
        #expect(!app.isClearingKeptMail)
        // The inbox was listed again from the server.
        #expect(engine.calls.last { $0.hasPrefix("refresh") } != nil)
    }
}
