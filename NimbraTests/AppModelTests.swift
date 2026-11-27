import Foundation
import NimbraCore
import Testing
@testable import Nimbra

@MainActor
struct AppModelTests {
    @Test func noAccountIsWelcome() async {
        let app = Fixture.app(FakeEngine())
        await app.start()
        #expect(app.phase == .welcome)
        #expect(app.accountID == nil)
    }

    @Test func showsTheDefaultAccountsInboxFromTheDeviceThenFresh() async throws {
        let engine = FakeEngine(accounts: [Fixture.imap, Fixture.gmail])
        let inbox = ListingKey(account: "g1", mailbox: .inbox)
        engine.state.withLock { state in
            state.cached[inbox] = [Fixture.row("old")]
            state.fresh[inbox] = ThreadPage(threads: [Fixture.row("new", unread: true), Fixture.row("old")], nextPage: "p2")
            state.counts["g1"] = [
                LabelCount(labelId: "INBOX", unread: 7, total: 20),
                LabelCount(labelId: "CATEGORY_PERSONAL", unread: 4, total: 9),
            ]
        }
        let app = Fixture.app(engine)
        await app.start()

        #expect(app.phase == .signedIn)
        #expect(app.accountID == "g1")
        #expect(app.hasSplitInbox("g1"))
        // The whole Inbox comes first, before Gmail's categories.
        #expect(app.split == nil)
        #expect(app.inboxMailbox == .inbox)
        #expect(app.inboxThreads.map(\.id.thread) == ["new", "old"])
        #expect(app.inboxListing?.nextPage == "p2")
        #expect(app.inboxListing?.isFresh == true)
        #expect(app.unreadCount(nil) == 7)
        #expect(app.unreadCount(.primary) == 4)
    }

    @Test func aCategoryChipShowsItsListAndAnotherAccountStartsAtInbox() async {
        let other = NimbraCore.Account(id: "g2", email: "ben@gmail.com", kind: .gmail, isDefault: false)
        let engine = FakeEngine(accounts: [Fixture.gmail, other])
        let primary = ListingKey(account: "g1", mailbox: .split(category: .primary))
        engine.state.withLock { $0.cached[primary] = [Fixture.row("p")] }
        let app = Fixture.app(engine)
        await app.start()

        await app.selectSplit(.primary)
        #expect(app.inboxMailbox == .split(category: .primary))
        #expect(app.inboxThreads.map(\.id.thread) == ["p"])

        await app.selectAccount("g2")
        #expect(app.split == nil)
        #expect(app.inboxMailbox == .inbox)
    }

    @Test func anAccountWithItsOwnServersHasOneInbox() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("a")] }
        let app = Fixture.app(engine)
        await app.start()
        #expect(!app.hasSplitInbox("i1"))
        #expect(app.inboxMailbox == .inbox)
        #expect(app.inboxThreads.map(\.id.thread) == ["a"])
    }

    @Test func rowsNameTheAccountsOwnLabelsOnly() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("a", labels: ["INBOX", "L1"])] }
        let app = Fixture.app(engine)
        await app.start()
        #expect(app.inboxThreads.first?.labels == ["Travel"])
    }

    @Test func loadMoreKeepsThePageAfterWithoutRepeats() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        let inbox = ListingKey(account: "i1", mailbox: .inbox)
        engine.state.withLock { state in
            state.fresh[inbox] = ThreadPage(threads: [Fixture.row("a"), Fixture.row("b")], nextPage: "p2")
            state.more[inbox] = ThreadPage(threads: [Fixture.row("b"), Fixture.row("c")], nextPage: nil)
        }
        let app = Fixture.app(engine)
        await app.start()
        await app.loadMoreInbox()
        #expect(app.inboxThreads.map(\.id.thread) == ["a", "b", "c"])
        #expect(app.inboxListing?.nextPage == nil)
    }

    @Test func readingShowsAtOnceAndGoesToTheEngine() async throws {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("a", unread: true)] }
        let app = Fixture.app(engine)
        await app.start()
        let id = try #require(app.inboxThreads.first?.id)
        await app.markRead(id)
        #expect(app.thread(id)?.isUnread == false)
        #expect(engine.calls.contains("apply a markRead"))
    }

    @Test func aRefusedActionIsUndoneAndSaysWhy() async throws {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("a")] }
        let app = Fixture.app(engine)
        await app.start()
        let id = try #require(app.inboxThreads.first?.id)
        engine.fail("apply", with: .Failed(message: "The server said no."))
        await app.markDone(id)
        #expect(app.inboxThreads.map(\.id) == [id])
        #expect(app.alert == .failed("The server said no."))
    }

    @Test func offlineIsAStateNotAnAlert() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("a")] }
        engine.fail("refreshMailbox", with: .Offline)
        let app = Fixture.app(engine)
        await app.start()
        #expect(app.isOffline)
        #expect(app.alert == nil)
        // What the device keeps still shows.
        #expect(app.inboxThreads.map(\.id.thread) == ["a"])
        await app.refreshAll()
        #expect(!app.isOffline)
    }

    @Test func aSignInThatIsGoneMarksTheAccount() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.fail("refreshMailbox", with: .SignedOut(accountId: "g1"))
        let app = Fixture.app(engine)
        await app.start()
        #expect(app.signedOut == ["g1"])
        #expect(app.alert == nil)
    }

    @Test func doneAndSnoozeTakeTheThreadOut() async throws {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("a"), Fixture.row("b")] }
        let app = Fixture.app(engine)
        await app.start()
        await app.markDone(.init(account: "i1", thread: "a"))
        await app.snooze(.init(account: "i1", thread: "b"), until: .now.addingTimeInterval(3600), onlyIfNoReply: true)
        #expect(app.inboxThreads.isEmpty)
        #expect(engine.calls.contains("apply a done"))
        #expect(engine.calls.contains("snooze b true"))
    }

    @Test func removingTheLastAccountGoesBackToWelcome() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        let app = Fixture.app(engine)
        await app.start()
        await app.removeAccount("i1")
        #expect(app.accounts.isEmpty)
        #expect(app.phase == .welcome)
    }

    @Test func choosingTheDefaultGoesToTheEngine() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, Fixture.imap])
        let app = Fixture.app(engine)
        await app.start()
        await app.makeDefault("i1")
        #expect(app.accounts.first { $0.id == "i1" }?.isDefault == true)
        #expect(app.accounts.first { $0.id == "g1" }?.isDefault == false)
    }

    // MARK: Signing in

    @Test func signInWithoutAClientIdSaysItIsNotSetUp() async {
        let engine = FakeEngine()
        let app = Fixture.app(engine, oauth: OAuthConfig(googleClientID: nil, microsoftClientID: "", bundleID: "com.riangle.nimbra"))
        await app.start()
        let added = await app.signIn(with: .google) { _, _ in
            Issue.record("the page should not open")
            return nil
        }
        #expect(!added)
        #expect(app.alert == .notConfigured(.google))
        #expect(engine.calls.isEmpty)
    }

    @Test func googleSignInComesBackToTheAppsRedirect() async {
        let engine = FakeEngine()
        let app = Fixture.app(engine)
        await app.start()
        var scheme: String?
        let added = await app.signIn(with: .google) { url, callback in
            #expect(url.host() == "accounts.google.com")
            scheme = callback
            return URL(string: "com.googleusercontent.apps.1234-abc:/oauth2redirect?code=c&state=s")
        }
        #expect(added)
        #expect(scheme == "com.googleusercontent.apps.1234-abc")
        #expect(engine.calls.first == "beginGoogle com.googleusercontent.apps.1234-abc:/oauth2redirect")
        #expect(engine.calls.contains("finishGoogle request-1 com.googleusercontent.apps.1234-abc:/oauth2redirect?code=c&state=s"))
        #expect(app.phase == .signedIn)
        #expect(app.accountID == "added")
    }

    @Test func closingTheSignInPageForgetsItQuietly() async {
        let engine = FakeEngine()
        let app = Fixture.app(engine)
        await app.start()
        let added = await app.signIn(with: .microsoft) { _, scheme in
            #expect(scheme == "msauth.com.riangle.nimbra")
            return nil
        }
        #expect(!added)
        #expect(app.alert == nil)
        #expect(engine.calls == ["beginMicrosoft msauth.com.riangle.nimbra://auth", "cancel request-2"])
    }
}
