import Foundation
import NimbraCore
import Testing
@testable import Nimbra

/// Sending: the undo time on a test clock, what `deliver` says, waiting for the
/// connection and catching up, Send later. No network.
@MainActor
struct SendingTests {
    @Test func aSentMessageIsHeldForTheUndoTimeThenDelivered() async throws {
        let (app, engine, clock) = await started()
        let composer = writing(app)
        let sending = Task { await app.send(composer) }

        #expect(await eventually { app.outbox.count == 1 })
        #expect(app.composer == nil)
        #expect(app.toast?.action == .undoSend(app.outbox[0].id))
        #expect(app.toast?.text == "Sending…")
        let send = try #require(engine.state.withLock { $0.sends.first })

        clock.advance(by: .seconds(9))
        try await Task.sleep(for: .milliseconds(30))
        #expect(send.deliveries == 0)

        clock.advance(by: .seconds(1))
        await sending.value
        #expect(send.deliveries == 1)
        #expect(app.outbox.isEmpty)
        #expect(app.toast?.text == "Message sent.")
    }

    @Test func undoBringsTheMessageBackAndNothingIsSent() async throws {
        let (app, engine, clock) = await started()
        let composer = writing(app)
        let sending = Task { await app.send(composer) }
        #expect(await eventually { app.outbox.count == 1 })
        let send = try #require(engine.state.withLock { $0.sends.first })

        clock.advance(by: .seconds(5))
        #expect(await app.undoSend(app.outbox[0].id))
        #expect(app.composer === composer)
        #expect(!composer.isSending)
        #expect(app.outbox.isEmpty)
        #expect(app.toast == nil)

        clock.advance(by: .seconds(10))
        await sending.value
        #expect(send.deliveries == 0)
        #expect(send.stage() == .over)
    }

    @Test func undoIsTooLateOnceItIsDelivered() async {
        let (app, _, clock) = await started()
        let sending = Task { await app.send(writing(app)) }
        #expect(await eventually { app.outbox.count == 1 })
        let id = app.outbox[0].id
        clock.advance(by: .seconds(10))
        await sending.value
        #expect(!(await app.undoSend(id)))
    }

    @Test func noUndoTimeSendsAtOnce() async throws {
        let (app, engine, _) = await started(undo: 0)
        await app.send(writing(app))
        let send = try #require(engine.state.withLock { $0.sends.first })
        #expect(send.deliveries == 1)
        #expect(app.toast?.text == "Message sent.")
    }

    @Test func whatTheEngineRefusesStaysInTheComposer() async {
        let (app, engine, _) = await started()
        let composer = Composer(kind: .new, from: "g1")
        app.presentedComposer = composer
        await app.send(composer)
        #expect(app.composer === composer)
        #expect(composer.notice == "Add someone to send it to.")
        #expect(!composer.isSending)
        #expect(engine.state.withLock { $0.sends.isEmpty })
    }

    @Test func offlineItWaitsAndGoesWithTheCatchUp() async {
        let (app, engine, _) = await started(undo: 0)
        engine.state.withLock { $0.outcomes = [.waitingForConnection] }
        await app.send(writing(app))
        #expect(engine.calls.contains("wait Lunch"))
        #expect(app.isOffline)
        #expect(app.waitingMessages["g1"] == 1)
        #expect(app.connectionSubtitle == "OFFLINE · 1 WAITING")
        #expect(app.toast?.text == "You’re offline. It’s sent when you’re back.")
        #expect(app.toast?.icon == .wifiOff)

        engine.state.withLock { $0.catchUp = CatchUpResult(changes: 0, sent: 1, movedToDrafts: [], done: true) }
        await app.catchUpOutbox()
        #expect(engine.calls.contains("catchUp g1"))
        #expect(app.waitingMessages["g1"] == 0)
        #expect(!app.isOffline)
        #expect(app.connectionSubtitle == nil)
        #expect(app.toast?.text == "Back online. The waiting message was sent.")
    }

    @Test func aMessageThatMayHaveGoneIsNeverSentAgainBySelf() async {
        let (app, engine, _) = await started(undo: 0)
        engine.state.withLock { $0.outcomes = [.maybeSent(inDrafts: true)] }
        await app.send(writing(app))
        #expect(app.toast?.text == "“Lunch” may already be sent: check Sent before sending it again. It is in Drafts.")
        #expect(app.composer == nil)
    }

    @Test func aRefusedMessageComesBackToBeFixed() async {
        let (app, engine, _) = await started(undo: 0)
        engine.state.withLock { $0.outcomes = [.refused(message: "Mailbox full.")] }
        let composer = writing(app)
        await app.send(composer)
        #expect(app.composer === composer)
        #expect(composer.notice == "Not sent: Mailbox full.")
        #expect(!composer.isSending)
    }

    @Test func aSignedOutAccountKeepsItForLater() async {
        let (app, engine, _) = await started(undo: 0)
        engine.state.withLock { $0.outcomes = [.signedOut] }
        await app.send(writing(app))
        #expect(app.signedOut.contains("g1"))
        #expect(app.toast?.text.contains("signed out") == true)
    }

    @Test func whatAnEarlierRunLeftIsPickedUpOnce() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let left = SampleSend(account: "g1", message: message("Left"), deliverAtMs: 0) { .sent }
        engine.state.withLock {
            $0.unsent = UnsentReport(toSend: [left], movedToDrafts: [])
        }
        let app = Fixture.app(engine)
        app.clock = TestClock().clock
        await app.start()
        await app.catchUpOutbox()
        await app.catchUpOutbox()
        #expect(left.deliveries == 1)
        #expect(engine.calls.filter { $0 == "unsent g1" }.count == 1)
        #expect(app.toast?.text == "Sent “Left”, which was waiting.")
    }

    @Test func whatWentToDraftsIsSaid() {
        let moved = MovedToDrafts(subject: "Contract", why: .maybeSent, inDrafts: false)
        #expect(AppModel.leftBehind(moved) == "“Contract” may already be sent: check Sent before sending it again. It is kept on this iPhone.")
        #expect(AppModel.quoted("  ") == "A message")
        #expect(AppModel.quoted(String(repeating: "a", count: 50)).count == 42)
    }

    @Test func sendLaterKeepsTheDraftForItsTime() async {
        let (app, engine, clock) = await started()
        let composer = writing(app)
        let at = clock.now.addingTimeInterval(3600)
        #expect(await app.scheduleSend(composer, at: at))
        #expect(engine.calls.contains("schedule \(at.milliseconds)"))
        #expect(app.composer == nil)
        #expect(app.scheduledSends["g1"]?.map(\.subject) == ["Lunch"])

        let first = app.scheduledSends["g1"]![0]
        await app.cancelScheduled(first, account: "g1")
        #expect(app.scheduledSends["g1"]?.isEmpty == true)
        #expect(await app.outboxDeadline() == nil)
    }

    @Test func theOutboxDeadlineIsTheSoonestRetry() async {
        let (app, engine, clock) = await started()
        engine.state.withLock { $0.waiting["g1"] = 1 }
        #expect(await app.outboxDeadline() == clock.now.addingTimeInterval(15))
    }

    @Test func aToastsUndoRunsOnceAndGoesWithTheToast() async {
        let (app, _, clock) = await started()
        var undone = 0
        app.show(Toast(icon: .done, text: "Done."), undo: { undone += 1 })
        guard case .undo(let id) = app.toast?.action else {
            Issue.record("no undo")
            return
        }
        await app.run(.undo(id))
        await app.run(.undo(id))
        #expect(undone == 1)
        #expect(app.toast == nil)

        app.show(Toast(icon: .done, text: "Done."), undo: { undone += 1 })
        guard case .undo(let second) = app.toast?.action else { return }
        // Both toasts' timers wait on the clock.
        #expect(await eventually { clock.sleeping == 2 })
        clock.advance(by: .seconds(4))
        #expect(await eventually { app.toast == nil })
        await app.run(.undo(second))
        #expect(undone == 1)
    }

    // MARK: Helpers

    private func started(undo: UInt32 = 10) async -> (AppModel, FakeEngine, TestClock) {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let clock = TestClock()
        engine.state.withLock {
            $0.undoSendSeconds = undo
            $0.now = clock.now.milliseconds
        }
        let app = Fixture.app(engine)
        app.clock = clock.clock
        await app.start()
        return (app, engine, clock)
    }

    private func writing(_ app: AppModel) -> Composer {
        let composer = Composer(kind: .new, from: "g1")
        composer.to = ["ana@example.com"]
        composer.subject = "Lunch"
        composer.text = "Friday?"
        app.presentedComposer = composer
        return composer
    }

    private func message(_ subject: String) -> OutgoingMessage {
        OutgoingMessage(to: "a@b.co", cc: "", bcc: "", subject: subject, body: "", html: nil, files: [], kept: [], reply: nil)
    }
}
