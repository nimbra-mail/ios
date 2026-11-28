import Foundation
import NimbraCore
import Testing
@testable import Nimbra

/// What the iPhone does as the Mac does: neighbours read ahead, the inbox opened where it
/// was left, Delete forever and Open in Gmail, the words for mail that has none, the
/// search tips, the day's line and contacts learnt from mail. No network.
@MainActor
struct ParityTests {
    // MARK: Neighbours

    @Test func openingAThreadReadsTheOnesAboveAndBelowWithoutMarkingThemRead() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { state in
            state.cached[ListingKey(account: "i1", mailbox: .inbox)] = ["a", "b", "c", "d"].map { Fixture.row($0, unread: true) }
            // Already on the device: not read again.
            state.kept["c"] = NimbraCore.MailThread(id: "c", messages: [])
        }
        let app = Fixture.app(engine)
        await app.start()
        await app.open(Nimbra.MailThread.ID(account: "i1", thread: "b"))
        await app.preparing?.value

        #expect(engine.calls.contains("read b"))
        #expect(engine.calls.contains("read a"))
        #expect(!engine.calls.contains("read c"))
        #expect(!engine.calls.contains("read d"))
        // Only the one opened is marked read.
        #expect(engine.calls.filter { $0.hasPrefix("apply") } == ["apply b markRead"])
        #expect(app.opened[Nimbra.MailThread.ID(account: "i1", thread: "a")] == nil)
        #expect(app.inboxThreads.first { $0.id.thread == "a" }?.isUnread == true)
    }

    @Test func neighboursAreInTheListShownAndAtItsEnds() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = ["a", "b", "c"].map { Fixture.row($0) } }
        let app = Fixture.app(engine)
        await app.start()
        let id = { (thread: String) in Nimbra.MailThread.ID(account: "i1", thread: thread) }
        #expect(app.neighbours(of: id("b")) == [id("c"), id("a")])
        #expect(app.neighbours(of: id("a")) == [id("b")])
        #expect(app.neighbours(of: id("c")) == [id("b")])
        #expect(app.neighbours(of: id("z")).isEmpty)
    }

    // MARK: Where it was left

    @Test func theInboxOpensWhereItWasLeft() async {
        let other = NimbraCore.Account(id: "g2", email: "ben@gmail.com", kind: .gmail, isDefault: false)
        let engine = FakeEngine(accounts: [Fixture.gmail, other])
        let defaults = UserDefaults(suiteName: "tests.\(UUID().uuidString)")!
        let first = Fixture.app(engine)
        first.placeStore = PlaceStore(defaults: defaults)
        await first.start()
        #expect(first.accountID == "g1")
        await first.selectAccount("g2")
        await first.selectSplit(.promotions)

        let again = Fixture.app(engine)
        again.placeStore = PlaceStore(defaults: defaults)
        await again.start()
        #expect(again.accountID == "g2")
        #expect(again.split == .promotions)
        #expect(again.inboxMailbox == .split(category: .promotions))
    }

    @Test func aPlaceWhoseAccountIsGoneOpensTheDefault() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, Fixture.imap])
        let defaults = UserDefaults(suiteName: "tests.\(UUID().uuidString)")!
        let store = PlaceStore(defaults: defaults)
        store.place = PlaceStore.Place(account: "gone", split: .social)
        let app = Fixture.app(engine)
        app.placeStore = store
        await app.start()
        #expect(app.accountID == "g1")
        #expect(app.split == nil)
        #expect(store.place == PlaceStore.Place(account: "g1", split: nil))

        // An account with one inbox has no category to put back.
        store.place = PlaceStore.Place(account: "i1", split: .social)
        let other = Fixture.app(engine)
        other.placeStore = store
        await other.start()
        #expect(other.accountID == "i1")
        #expect(other.split == nil)
    }

    // MARK: Trash

    @Test func deleteForeverTakesTheThreadOutForGood() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let trash = ListingKey(account: "g1", mailbox: .trash)
        engine.state.withLock { $0.cached[trash] = [Fixture.row("t1"), Fixture.row("t2")] }
        let app = Fixture.app(engine)
        await app.start()
        await app.show(trash)
        let id = Nimbra.MailThread.ID(account: "g1", thread: "t1")

        #expect(await app.deleteForever(id) == .deleted)
        #expect(engine.calls.contains("deleteThread g1 t1"))
        #expect(app.listings[trash]?.threads.map(\.id.thread) == ["t2"])
        #expect(app.toast?.text == "Deleted forever")
        #expect(app.toast?.action == nil)
    }

    @Test func deleteForeverAsksForFullAccessAndPutsTheThreadBack() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let trash = ListingKey(account: "g1", mailbox: .trash)
        engine.state.withLock { $0.cached[trash] = [Fixture.row("t1")] }
        let app = Fixture.app(engine)
        await app.start()
        await app.show(trash)
        let id = Nimbra.MailThread.ID(account: "g1", thread: "t1")

        engine.fail("deleteThread", with: .NeedsFullAccess)
        #expect(await app.deleteForever(id) == .needsFullAccess)
        #expect(app.listings[trash]?.threads.map(\.id.thread) == ["t1"])
        #expect(app.alert == nil)

        let granted = await app.grantFullAccess(to: "g1") { _, _ in
            URL(string: "com.googleusercontent.apps.1234-abc:/oauth2redirect?code=c&state=s")
        }
        #expect(granted)
        #expect(engine.calls.contains("beginGoogle com.googleusercontent.apps.1234-abc:/oauth2redirect full"))

        // Refused for another reason: back in the list, said in an alert.
        engine.fail("deleteThread", with: .Failed(message: "No."))
        #expect(await app.deleteForever(id) == .failed)
        #expect(app.listings[trash]?.threads.map(\.id.thread) == ["t1"])
        #expect(app.alert == .failed("No."))

        // Already gone from the server: deleted all the same.
        engine.fail("deleteThread", with: .NotFound)
        #expect(await app.deleteForever(id) == .deleted)
        #expect(app.listings[trash]?.threads.isEmpty == true)
    }

    @Test func openInGmailIsForGmailThreadsWithPlainIds() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, Fixture.imap])
        let app = Fixture.app(engine)
        await app.start()
        #expect(app.gmailURL(for: .init(account: "g1", thread: "18c2fab")) == URL(string: "https://mail.google.com/mail/?authuser=ana%40gmail.com#all/18c2fab"))
        #expect(app.gmailURL(for: .init(account: "i1", thread: "18c2fab")) == nil)
        #expect(app.gmailURL(for: .init(account: "g1", thread: "../x")) == nil)
        #expect(app.gmailURL(for: .init(account: "g1", thread: "")) == nil)
    }

    // MARK: Words

    @Test func mailWithoutASubjectOrSenderSaysSoAsTheMacDoes() {
        var thread = Nimbra.MailThread(id: .init(account: "g1", thread: "t"), subject: "  ", sender: Person(name: "", email: ""), snippet: "", date: .now, messageCount: 1)
        #expect(thread.shownSubject == "Untitled")
        #expect(thread.shownSender(drafts: true) == "Draft")
        #expect(thread.shownSender(drafts: false) == "Unknown sender")
        #expect(!thread.namesSomeone)
        thread.subject = "(no subject)"
        thread.sender = Person(name: "Unknown sender", email: "")
        #expect(thread.shownSubject == "Untitled")
        #expect(thread.shownSender(drafts: true) == "Draft")
        thread.subject = "Plan"
        thread.sender = Person(name: "", email: "ana@example.com")
        #expect(thread.shownSubject == "Plan")
        #expect(thread.shownSender(drafts: true) == "ana@example.com")
        thread.sender = Person(name: "Ana", email: "ana@example.com")
        #expect(thread.shownSender(drafts: false) == "Ana")
    }

    @Test func theReaderNamesYourOwnAddressMe() {
        let own = ["Ana@Gmail.com"]
        #expect(Nimbra.MailThread.shownFrom(Person(name: "", email: "ana@gmail.com"), own: own, drafts: false) == "Me")
        #expect(Nimbra.MailThread.shownFrom(Person(name: "Ana Lima", email: "ana@gmail.com"), own: own, drafts: false) == "Ana Lima")
        #expect(Nimbra.MailThread.shownFrom(Person(name: "", email: "ben@x.org"), own: own, drafts: false) == "ben@x.org")
        #expect(Nimbra.MailThread.shownFrom(Person(name: "", email: ""), own: own, drafts: false) == "Unknown sender")
        #expect(Nimbra.MailThread.shownFrom(Person(name: "", email: ""), own: own, drafts: true) == "Draft")
    }

    @Test func aMessageWithNothingInItHasNoContent() {
        let empty = Message(from: SampleData.mira, to: [], date: .now, body: " \n")
        #expect(empty.hasNoContent)
        #expect(Message(from: SampleData.mira, to: [], date: .now, body: "", html: "<div dir=\"ltr\"><br>&nbsp;</div><style>p{}</style>").hasNoContent)
        #expect(!Message(from: SampleData.mira, to: [], date: .now, body: "Hi").hasNoContent)
        #expect(!Message(from: SampleData.mira, to: [], date: .now, body: "", html: "<p>Hi</p>").hasNoContent)
        #expect(!Message(from: SampleData.mira, to: [], date: .now, body: "", html: "<img src=\"cid:x\">").hasNoContent)
    }

    // MARK: Search tips

    @Test func theSearchTipsAreTheMacs() {
        #expect(SearchTip.all.map(\.words) == ["from:", "cc:", "bcc:", "has:attachment", "is:unread", "newer_than:7d"])
        #expect(SearchTip.all[0].query == "from:")
        #expect(SearchTip.all[3].query == "has:attachment ")
    }

    // MARK: The day's line

    @Test func everyDayHasItsLineBeforeAnyComesBack() {
        #expect(DailyLine.lines.count == 365)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let first = calendar.date(from: DateComponents(year: 2026, month: 12, day: 25, hour: 12))!
        let indices = (0..<365).map { DailyLine.index(for: calendar.date(byAdding: .day, value: $0, to: first)!, calendar: calendar) }
        #expect(Set(indices).count == 365)
        #expect(DailyLine.index(for: calendar.date(byAdding: .day, value: 365, to: first)!, calendar: calendar) == indices[0])
        // The Mac's day for each date (chrono's days from the common era, round the year).
        #expect(DailyLine.daysFromCommonEra(year: 1970, month: 1, day: 1) == 719_163)
        #expect(DailyLine.daysFromCommonEra(year: 1, month: 1, day: 1) == 1)
        #expect(indices[0] == 120)
        #expect(String(localized: DailyLine.lines[120]) == "Look closely at a leaf.")
    }

    @Test func aQuoteAndItsAuthorComeApart() {
        let quote = DailyLine.split("“Less is more.” Ludwig Mies van der Rohe")
        #expect(quote.line == "“Less is more.”")
        #expect(quote.author == "Ludwig Mies van der Rohe")
        let plain = DailyLine.split("Learn the name of one tree on your street.")
        #expect(plain.line == "Learn the name of one tree on your street.")
        #expect(plain.author == nil)
        // A line that only uses quotation marks is not a quote with an author.
        #expect(DailyLine.split("“Be curious.”").author == nil)
        for line in DailyLine.lines.map({ String(localized: $0) }) {
            #expect(!line.contains("\u{2014}") && !line.contains("\u{2013}"))
        }
    }

    // MARK: Contacts

    @Test func contactsAreLearntAPageAtATimeUntilThereAreNoMore() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, Fixture.imap])
        engine.state.withLock { $0.contactSteps = ["g1": 2, "i1": 1] }
        let app = Fixture.app(engine)
        let clock = TestClock()
        app.clock = clock.clock
        await app.start()
        let learning = Task { await app.learnContacts() }

        // Nothing before the first pause.
        #expect(await eventually { clock.sleeping == 1 })
        #expect(!engine.calls.contains { $0.hasPrefix("learnContacts") })
        for _ in 0..<3 {
            #expect(await eventually { clock.sleeping == 1 })
            clock.advance(by: .seconds(30))
        }
        await learning.value
        #expect(engine.calls.filter { $0.hasPrefix("learnContacts") } == ["learnContacts g1", "learnContacts g1", "learnContacts i1"])
        #expect(app.contactsLearnt == ["g1", "i1"])

        // Done for this run: coming back to the front learns nothing more.
        await app.learnContacts()
        #expect(engine.calls.filter { $0.hasPrefix("learnContacts") }.count == 3)
    }

    @Test func offlineContactsAreLearntTheNextTime() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.state.withLock { $0.contactSteps = ["g1": 1] }
        let app = Fixture.app(engine)
        let clock = TestClock()
        app.clock = clock.clock
        await app.start()
        engine.fail("learnContacts", with: .Offline)
        let learning = Task { await app.learnContacts() }
        #expect(await eventually { clock.sleeping == 1 })
        clock.advance(by: .seconds(30))
        await learning.value
        #expect(app.contactsLearnt.isEmpty)

        // Leaving the front cancels the wait.
        let cancelled = Task { await app.learnContacts() }
        #expect(await eventually { clock.sleeping == 1 })
        cancelled.cancel()
        await cancelled.value
        #expect(engine.calls.filter { $0.hasPrefix("learnContacts") }.count == 1)
    }
}
