import Foundation
import NimbraCore
import Testing
@testable import Nimbra

/// New mail, the snoozes' returns, the badge, the permission flow and the answers to a
/// notification, on a fake engine and a fake notification center.
@MainActor
struct NotificationsTests {
    private func news(named: [String], more: UInt32 = 0, unread: [String]? = nil, notify: Bool = true, cursor: String = "c2") -> SyncResult {
        SyncResult(
            cursor: cursor, changedThreads: named, newUnreadInbox: unread ?? named,
            named: named.map { Fixture.row($0, unread: true) }, moreNew: more, notify: notify, expired: false
        )
    }

    private func signedIn(_ engine: FakeEngine, permission: NotificationPermission = .allowed) async -> (AppModel, FakeNotifier) {
        let app = Fixture.app(engine)
        let notifier = app.notifier as! FakeNotifier
        notifier.status = permission
        await app.start()
        await app.loadNotificationSettings()
        return (app, notifier)
    }

    // MARK: Rules

    @Test func threeNamedThenACount() {
        let notes = MailNotification.newMail(news(named: ["a", "b", "c"], more: 2), account: "g1", muted: false, sound: true)
        #expect(notes.map(\.id) == ["acct:g1:a", "acct:g1:b", "acct:g1:c", "acct:g1:more"])
        #expect(notes[0].title == "Ben")
        #expect(notes[0].subtitle == "Subject a")
        #expect(notes[0].body == "Snippet")
        #expect(notes[0].hasActions && notes[0].group == "acct:g1" && notes[0].sound)
        #expect(notes[3].body == "2 more new messages")
        #expect(!notes[3].hasActions)
        let one = MailNotification.newMail(news(named: [], more: 1), account: "g1", muted: false, sound: false)
        #expect(one.map(\.body) == ["1 more new message"])
        #expect(one.allSatisfy { !$0.sound })
    }

    @Test func nothingWhenOffOrTheAccountIsSwitchedOff() {
        #expect(MailNotification.newMail(news(named: ["a"], notify: false), account: "g1", muted: false, sound: true).isEmpty)
        #expect(MailNotification.newMail(news(named: ["a"]), account: "g1", muted: true, sound: true).isEmpty)
    }

    @Test func idsReadBackAsTheMacWritesThem() {
        #expect(MailNotification.parse("acct:g1:t1")?.account == "g1")
        #expect(MailNotification.parse("acct:g1:t1")?.thread == "t1")
        #expect(MailNotification.parse("acct:g1:more").map { $0.thread == nil } == true)
        #expect(MailNotification.parse("test") == nil)
        #expect(MailNotification.parse("acct::t") == nil)
    }

    @Test func returnsAreTheSnoozesAheadSoonestFirstWithinTheLimit() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let ms = now.milliseconds
        let snoozed: [(account: String, thread: SnoozedThread)] = [
            ("g1", Fixture.snoozed("later", at: ms + 7_200_000)),
            ("g1", Fixture.snoozed("past", at: ms - 1)),
            ("g1", Fixture.snoozed("soon", at: ms + 60_000, reminder: true)),
            ("i1", Fixture.snoozed("muted", at: ms + 60_000)),
        ]
        let returns = MailNotification.returns(snoozed, now: now, muted: ["i1"], sound: true, limit: 2)
        #expect(returns.map(\.id) == ["acct:g1:soon", "acct:g1:later"])
        #expect(returns[0].title == "No reply yet")
        #expect(returns[1].title == "Back from snooze")
        #expect(returns[1].body == "Subject later")
        #expect(returns[0].fireDate == Date(milliseconds: ms + 60_000))
    }

    // MARK: New mail

    @Test func newMailNotifiesWhatTheEngineNamesNeverBlockedSenders() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let (app, notifier) = await signedIn(engine)
        // The first look starts from now: nothing to notify, and the cursor is kept.
        await app.checkForNewMail(canAsk: true)
        #expect(engine.calls.contains("check g1 -"))
        #expect(notifier.shown.isEmpty)
        // "blocked" got new mail, but the engine put it away and did not name it.
        engine.state.withLock { $0.changes["g1"] = news(named: ["a"], unread: ["a", "blocked"]) }
        await app.checkForNewMail(canAsk: true)
        #expect(engine.calls.contains("check g1 c-g1"))
        #expect(notifier.shown.map(\.id) == ["acct:g1:a"])
        // The next look reads from where this one ended.
        await app.checkForNewMail(canAsk: true)
        #expect(engine.calls.contains("check g1 c2"))
    }

    @Test func soundFollowsPreferencesAndAnAccountCanBeSwitchedOff() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.state.withLock { $0.preferences.notificationSound = false }
        let (app, notifier) = await signedIn(engine)
        engine.state.withLock { $0.changes["g1"] = news(named: ["a"]) }
        await app.checkForNewMail(canAsk: true)
        #expect(notifier.shown.map(\.sound) == [false])

        await app.setNotifies(false, for: "g1")
        #expect(!app.notifies("g1"))
        #expect(app.notificationStore.muted == ["g1"])
        engine.state.withLock { $0.changes["g1"] = news(named: ["b"]) }
        await app.checkForNewMail(canAsk: true)
        #expect(notifier.shown.count == 1)
    }

    // MARK: Permission

    @Test func theFirstNewMailAsksOnceThenTheSystemPrompt() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let (app, notifier) = await signedIn(engine, permission: .notAsked)
        #expect(!app.isAskingForNotifications)

        // In the background it never asks.
        engine.state.withLock { $0.changes["g1"] = news(named: ["a"]) }
        await app.checkForNewMail(canAsk: false)
        #expect(!app.isAskingForNotifications)

        engine.state.withLock { $0.changes["g1"] = news(named: ["b"]) }
        await app.checkForNewMail(canAsk: true)
        #expect(app.isAskingForNotifications)
        #expect(notifier.shown.isEmpty)
        #expect(notifier.requests == 0)

        await app.turnOnNotifications()
        #expect(notifier.requests == 1)
        #expect(app.notificationPermission == .allowed)
        #expect(!app.isAskingForNotifications)
        #expect(app.notificationStore.asked)
    }

    @Test func notNowDoesNotAskAgain() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let (app, notifier) = await signedIn(engine, permission: .notAsked)
        engine.state.withLock { $0.changes["g1"] = news(named: ["a"]) }
        await app.checkForNewMail(canAsk: true)
        app.notNowNotifications()
        #expect(!app.isAskingForNotifications)
        engine.state.withLock { $0.changes["g1"] = news(named: ["b"]) }
        await app.checkForNewMail(canAsk: true)
        #expect(!app.isAskingForNotifications)
        #expect(notifier.requests == 0)
    }

    // MARK: Snoozes

    @Test func snoozeReturnsAreScheduledAndKeptInStep() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        engine.state.withLock { $0.snoozed["g1"] = [Fixture.snoozed("a", at: now.milliseconds + 3_600_000)] }
        let (app, notifier) = await signedIn(engine)
        app.clock = { now }
        await app.scheduleSnoozeReturns()
        #expect(notifier.pending.keys.sorted() == ["acct:g1:a"])
        #expect(notifier.pending["acct:g1:a"]?.fireDate == now.addingTimeInterval(3600))

        // Cancelled: its return goes too.
        engine.state.withLock { $0.snoozed["g1"] = [] }
        await app.scheduleSnoozeReturns()
        #expect(notifier.pending.isEmpty)

        // Notifications off in Preferences: nothing waits.
        engine.state.withLock { state in
            state.snoozed["g1"] = [Fixture.snoozed("b", at: now.milliseconds + 60_000)]
            state.preferences.notifications = false
        }
        await app.notificationPreferencesChanged()
        #expect(notifier.pending.isEmpty)
    }

    @Test func wakingShowsOnlyReturnsThatDidNotShowAndTakesBackAnsweredReminders() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let soon = start.milliseconds + 60_000
        engine.state.withLock {
            $0.snoozed["g1"] = [
                Fixture.snoozed("scheduled", at: soon),
                Fixture.snoozed("answered", at: soon, reminder: true),
            ]
        }
        let (app, notifier) = await signedIn(engine)
        app.clock = { start }
        await app.scheduleSnoozeReturns()
        #expect(notifier.pending.count == 2)

        // Their time comes: iOS shows both.
        app.clock = { start.addingTimeInterval(120) }
        notifier.pending = [:]
        notifier.delivered = ["acct:g1:scheduled", "acct:g1:answered"]
        // One the app never scheduled is due too.
        engine.state.withLock { state in
            state.snoozed["g1"]?.append(Fixture.snoozed("unscheduled", at: soon))
            state.due["g1"] = [Fixture.snoozed("scheduled", at: soon), Fixture.snoozed("unscheduled", at: soon)]
        }
        // Somebody replied to the reminder's thread: the engine drops it without waking it.
        engine.state.withLock { $0.answered = ["answered"] }
        await app.wakeDueSnoozes()

        #expect(engine.calls.contains("wakeDue g1"))
        #expect(notifier.shown.map(\.id) == ["acct:g1:unscheduled"])
        #expect(notifier.shown.first?.title == "Back from snooze")
        #expect(!notifier.delivered.contains("acct:g1:answered"))
        #expect(notifier.delivered.contains("acct:g1:scheduled"))
    }

    @Test func snoozingOffersUndoThatPutsTheThreadBack() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        let inbox = ListingKey(account: "i1", mailbox: .inbox)
        engine.state.withLock { $0.cached[inbox] = [Fixture.row("a"), Fixture.row("b"), Fixture.row("c")] }
        let (app, notifier) = await signedIn(engine)
        let id = MailThread.ID(account: "i1", thread: "b")
        let until = Date.now.addingTimeInterval(3600)

        let undo = await app.snooze(id, until: until, onlyIfNoReply: true)
        #expect(app.inboxThreads.map(\.id.thread) == ["a", "c"])
        #expect(undo?.thread.id == id)
        #expect(undo?.onlyIfNoReply == true)
        #expect(app.snoozed.map(\.id) == [id])
        #expect(notifier.pending.keys.sorted() == ["acct:i1:b"])

        await app.undoSnooze(undo!)
        #expect(engine.calls.contains("unsnooze b"))
        #expect(app.inboxThreads.map(\.id.thread) == ["a", "b", "c"])
        #expect(app.snoozed.isEmpty)
        #expect(notifier.pending.isEmpty)
    }

    @Test func aRefusedSnoozeLeavesTheThreadWhereItWas() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("a")] }
        let (app, _) = await signedIn(engine)
        engine.fail("snooze", with: .Failed(message: "no"))
        let undo = await app.snooze(MailThread.ID(account: "i1", thread: "a"), until: .now.addingTimeInterval(60))
        #expect(app.inboxThreads.map(\.id.thread) == ["a"])
        #expect(undo == nil)
    }

    // MARK: Badge and answers

    @Test func theBadgeIsTheEnginesCount() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.state.withLock { $0.badge = 7 }
        let (app, notifier) = await signedIn(engine)
        await app.updateBadge()
        #expect(notifier.badge == 7)
    }

    @Test func doneFromANotificationWakesWhatIsDueThenArchives() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("a"), Fixture.row("b")] }
        let (app, notifier) = await signedIn(engine)
        notifier.delivered = ["acct:i1:a"]

        await app.answerNotification(id: "acct:i1:a", action: SystemNotifier.done)
        let calls = engine.calls
        let woke = calls.firstIndex(of: "wakeDue i1")
        let done = calls.firstIndex(of: "apply a done")
        #expect(woke != nil && done != nil && woke! < done!)
        #expect(app.inboxThreads.map(\.id.thread) == ["b"])
        #expect(notifier.delivered.isEmpty)

        await app.answerNotification(id: "acct:i1:b", action: SystemNotifier.markRead)
        #expect(engine.calls.contains("apply b markRead"))
        // The summary has nothing to act on.
        await app.answerNotification(id: "acct:i1:more", action: SystemNotifier.done)
        #expect(!engine.calls.contains { $0.contains("more") })
    }

    @Test func tappingOpensTheThread() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("a")] }
        let (app, _) = await signedIn(engine)
        await app.answerNotification(id: "acct:i1:a", action: "com.apple.UNNotificationDefaultActionIdentifier")
        #expect(app.notifiedThread?.id == MailThread.ID(account: "i1", thread: "a"))
    }
}
