import Foundation
import NimbraCore

/// Sending, as the Mac sends: Send keeps the message on the device (`queueSend`) and holds
/// it for the undo time from Preferences, with Undo in the toast; then it is handed to the
/// server (`deliver`). Offline, it waits for the connection and goes with the next
/// catch-up. A message that may already have gone is never sent again by itself: it goes
/// to Drafts, and the toast says to check Sent. Send later keeps the draft for a time;
/// iOS runs Nimbra only now and then in the background, so it goes when Nimbra can run.
///
/// `catchUpOutbox()` and `outboxDeadline()`, what the background tasks call, are in
/// `AppModel+ComposeHooks`.
extension AppModel {
    // MARK: Send

    /// Sends the composer's message: checked and kept by the engine, then held for the
    /// undo time. What the engine refuses (no recipient, too large) stays in the composer
    /// as a notice.
    func send(_ composer: Composer) async {
        guard !composer.isSending else { return }
        composer.isSending = true
        draftSaves.removeValue(forKey: composer.id)?.cancel()
        // A draft save that is out finishes first: sending uses that draft up.
        while composer.isSaving { try? await clock.sleep(.milliseconds(100)) }
        let account = composer.from
        await pickUpUnsent(account)
        let message = composer.outgoing
        let draftID = composer.draftID
        let send: OutgoingSend
        do throws(MailError) {
            guard let host else { throw .notFound }
            send = try await host.call { try $0.queueSend(accountId: account, message: message, draftId: draftID) }
        } catch {
            composer.isSending = false
            switch error {
            case .invalid(let words), .failed(let words): composer.notice = words
            default:
                handle(error, account: account, report: false)
                composer.notice = error.message
            }
            return
        }
        if self.composer?.id == composer.id { self.composer = nil }
        let item = OutboxItem(send: send, composer: composer)
        outbox.append(item)
        let wait = Double(send.deliverAtMs() - clock.now().milliseconds) / 1000
        if wait > 0 {
            show(Toast(icon: .send, text: String(localized: "Sending…"), action: .undoSend(item.id), duration: nil))
            try? await clock.sleep(.seconds(wait))
        }
        await deliver(item.id)
    }

    /// Undo send: the held message comes back to the composer, as it was. False once it
    /// has left.
    @discardableResult
    func undoSend(_ id: OutboxItem.ID) async -> Bool {
        guard let index = outbox.firstIndex(where: { $0.id == id }), outbox[index].stage == .held else { return false }
        let item = outbox[index]
        let send = item.send
        let undone = await engine(for: item.account) { _ in send.undo() } ?? false
        guard undone, let index = outbox.firstIndex(where: { $0.id == id }) else { return false }
        outbox.remove(at: index)
        dismissToast()
        item.composer.isSending = false
        present(again: item.composer)
        return true
    }

    /// Hands a held message to the server, unless it was taken back.
    private func deliver(_ id: OutboxItem.ID) async {
        guard let index = outbox.firstIndex(where: { $0.id == id }), outbox[index].stage == .held else { return }
        outbox[index].stage = .delivering
        let item = outbox[index]
        let send = item.send
        if case .undoSend(id) = toast?.action {
            // Too late for Undo: the toast stays while it goes.
            toast?.action = nil
        }
        let outcome = await engine(for: item.account) { _ in send.deliver() } ?? .waitingForConnection
        outbox.removeAll { $0.id == id }
        await delivered(outcome, item: item)
    }

    /// What became of a message handed to the server, said calmly.
    private func delivered(_ outcome: SendOutcome, item: OutboxItem) async {
        let send = item.send
        let account = item.account
        let subject = Self.quoted(send.subject())
        switch outcome {
        case .sent:
            reached(account)
            show(Toast(icon: .send, text: String(localized: "Message sent.")))
        case .waitingForConnection:
            await engine(for: account) { $0.waitForConnection(send: send) }
            isOffline = true
            await loadPendingWork(account)
            show(Toast(
                icon: .wifiOff,
                text: send.isKept()
                    ? String(localized: "You’re offline. It’s sent when you’re back.")
                    : String(localized: "You’re offline. Keep Nimbra open until it’s sent: it can’t be kept on this iPhone."),
                duration: Toast.telling
            ))
        case .maybeSent(let inDrafts):
            let why = String(localized: "\(subject) may already be sent: check Sent before sending it again.")
            show(Toast(icon: .alert, text: why + " " + Self.whereNow(inDrafts: inDrafts), duration: Toast.telling))
        case .refused(let words):
            // Back on screen to fix, when nothing else is being written.
            let undone = composer == nil ? (await engine(for: account) { _ in send.undo() } ?? false) : false
            if undone {
                item.composer.isSending = false
                item.composer.notice = String(localized: "Not sent: \(words)")
                present(again: item.composer)
            } else {
                let saved = await engine(for: account) { _ in send.saveToDrafts() } ?? nil
                let why = String(localized: "\(subject) was not sent.")
                show(Toast(icon: .alert, text: why + " " + Self.whereNow(inDrafts: saved != nil), duration: Toast.telling))
            }
        case .signedOut:
            // Kept on the device: picked up again once the account is signed in.
            handle(.signedOut(accountID: account), account: account, report: false)
            show(Toast(icon: .alert, text: String(localized: "\(subject) was not sent: its account was signed out. Sign in again to send it."), duration: Toast.telling))
        case .notWaiting:
            break
        }
    }

    private func present(again composer: Composer) {
        if let open = self.composer, open.id != composer.id { close(open) }
        self.composer = composer
    }

    // MARK: Waiting for the connection

    /// While the app is in front: catches up now, then whenever the engine says something
    /// is due (a retry, a send later), until the task is cancelled.
    func keepOutboxMoving() async {
        while !Task.isCancelled {
            await catchUpOutbox()
            let next = await outboxDeadline()
            let wait = min(max((next ?? .distantFuture).timeIntervalSince(clock.now()), 5), 300)
            do { try await clock.sleep(.seconds(wait)) } catch { return }
        }
    }

    /// Messages waiting for the connection, in every account.
    var waitingCount: Int { waitingMessages.values.reduce(0, +) }

    /// The overline under the Inbox title while offline: "OFFLINE · 2 WAITING". Nil when
    /// online with nothing waiting.
    var connectionSubtitle: String? {
        guard isOffline || waitingCount > 0 else { return nil }
        guard isOffline else { return String(localized: "\(waitingCount) WAITING") }
        return waitingCount > 0
            ? String(localized: "OFFLINE · \(waitingCount) WAITING")
            : String(localized: "OFFLINE")
    }

    /// What an earlier run left unsent, once per account and run: what never left is sent,
    /// the rest went to Drafts and the toast says so.
    func pickUpUnsent(_ account: Account.ID) async {
        guard !pickedUp.contains(account) else { return }
        guard let report = await engine(for: account, work: { try $0.unsent(accountId: account) }) else { return }
        pickedUp.insert(account)
        if let first = report.movedToDrafts.first {
            show(Toast(icon: .alert, text: Self.leftBehind(first), duration: Toast.telling))
        }
        for send in report.toSend {
            let outcome = await engine(for: account) { _ in send.deliver() } ?? .waitingForConnection
            switch outcome {
            case .sent:
                show(Toast(icon: .send, text: String(localized: "Sent \(Self.quoted(send.subject())), which was waiting.")))
            case .waitingForConnection:
                await engine(for: account) { $0.waitForConnection(send: send) }
                isOffline = true
            case .maybeSent(let inDrafts):
                show(Toast(icon: .alert, text: String(localized: "\(Self.quoted(send.subject())) may already be sent: check Sent before sending it again.") + " " + Self.whereNow(inDrafts: inDrafts), duration: Toast.telling))
            case .refused:
                let saved = await engine(for: account) { _ in send.saveToDrafts() } ?? nil
                show(Toast(icon: .alert, text: String(localized: "\(Self.quoted(send.subject())) was not sent.") + " " + Self.whereNow(inDrafts: saved != nil), duration: Toast.telling))
            case .signedOut:
                handle(.signedOut(accountID: account), account: account, report: false)
            case .notWaiting:
                break
            }
        }
    }

    func loadPendingWork(_ account: Account.ID) async {
        guard let work = await engine(for: account, work: { try $0.pendingWork(accountId: account) }) else { return }
        waitingMessages[account] = Int(work.waitingMessages)
        queuedChanges[account] = Int(work.queuedChanges)
    }

    // MARK: Send later

    /// The times Send later offers from now.
    var sendLaterTimes: [SendLaterTime] { NimbraCore.sendLaterTimes() }

    /// Send later: saves the draft and keeps it for `date`. Nimbra sends it when it next
    /// runs at or after that time. False (with a notice in the composer) when it could not.
    @discardableResult
    func scheduleSend(_ composer: Composer, at date: Date) async -> Bool {
        guard !composer.isSending else { return false }
        composer.isSending = true
        draftSaves.removeValue(forKey: composer.id)?.cancel()
        while composer.isSaving { try? await clock.sleep(.milliseconds(100)) }
        let account = composer.from
        let message = composer.outgoing
        let draftID = composer.draftID
        let scheduled: ScheduledSend
        do throws(MailError) {
            guard let host else { throw .notFound }
            scheduled = try await host.call {
                try $0.scheduleSend(accountId: account, message: message, draftId: draftID, atMs: date.milliseconds)
            }
        } catch {
            composer.isSending = false
            switch error {
            case .invalid(let words), .failed(let words): composer.notice = words
            default:
                handle(error, account: account, report: false)
                composer.notice = error.message
            }
            return false
        }
        reached(account)
        if self.composer?.id == composer.id { self.composer = nil }
        await loadScheduled(account)
        let when = Date(milliseconds: scheduled.atMs).formatted(date: .abbreviated, time: .shortened)
        show(Toast(icon: .clock, text: String(localized: "Scheduled for \(when).")))
        return true
    }

    /// Takes a message off the Send later list; its draft stays in Drafts.
    func cancelScheduled(_ scheduled: ScheduledSend, account: Account.ID) async {
        let draft = scheduled.draftId
        await engine(for: account, report: true) { try $0.cancelScheduled(accountId: account, draftId: draft) }
        await loadScheduled(account)
    }

    func loadScheduled(_ account: Account.ID) async {
        guard let list = await engine(for: account, work: { try $0.scheduledSends(accountId: account) }) else { return }
        scheduledSends[account] = list
    }

    // MARK: The toast

    /// Shows a toast, replacing the one up; it goes after its time. With `undo`, its
    /// action is Undo, which runs it once (the closure is dropped when the toast goes).
    func show(_ toast: Toast, undo: (@MainActor () async -> Void)? = nil) {
        var toast = toast
        toastUndos = [:]
        if let undo {
            let id = UUID()
            toastUndos[id] = undo
            toast.action = .undo(id)
        }
        self.toast = toast
        guard let duration = toast.duration else { return }
        Task { [clock] in
            try? await clock.sleep(duration)
            if self.toast?.id == toast.id { self.dismissToast() }
        }
    }

    func dismissToast() {
        toast = nil
        toastUndos = [:]
    }

    /// The toast's action was tapped.
    func run(_ action: Toast.Action) async {
        switch action {
        case .undoSend(let id):
            await undoSend(id)
        case .undo(let id):
            guard let undo = toastUndos.removeValue(forKey: id) else { return }
            dismissToast()
            await undo()
        }
    }

    // MARK: Words

    /// A subject in quotes, shortened as the Mac shortens it; "A message" without one.
    static func quoted(_ subject: String) -> String {
        let subject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subject.isEmpty else { return String(localized: "A message") }
        let short = subject.count > 40 ? subject.prefix(39) + "…" : Substring(subject)
        return "“\(short)”"
    }

    static func whereNow(inDrafts: Bool) -> String {
        inDrafts ? String(localized: "It is in Drafts.") : String(localized: "It is kept on this iPhone.")
    }

    static func leftBehind(_ moved: MovedToDrafts) -> String {
        let subject = quoted(moved.subject)
        let why = switch moved.why {
        case .maybeSent: String(localized: "\(subject) may already be sent: check Sent before sending it again.")
        case .refused: String(localized: "\(subject) was not sent.")
        case .writing: String(localized: "\(subject) was still being written when Nimbra quit.")
        case .unscheduled: String(localized: "\(subject) was to be sent later, and Nimbra quit before keeping it.")
        }
        return why + " " + whereNow(inDrafts: moved.inDrafts)
    }

    static func backOnline(_ done: CatchUpResult) -> String {
        if let first = done.movedToDrafts.first {
            let subject = quoted(first.subject)
            let what = first.why == .maybeSent
                ? String(localized: "Back online. \(subject) may already be sent: check Sent.")
                : String(localized: "Back online. \(subject) could not be sent.")
            return what + " " + whereNow(inDrafts: first.inDrafts)
        }
        if done.sent == 1 { return String(localized: "Back online. The waiting message was sent.") }
        if done.sent > 1 { return String(localized: "Back online. \(done.sent) waiting messages were sent.") }
        return String(localized: "Back online.")
    }
}
