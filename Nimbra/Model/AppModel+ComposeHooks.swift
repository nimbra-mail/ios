import Foundation
import NimbraCore

/// What other areas call to write and send: the Thread screen (`startAnswer`,
/// `startUnsubscribe`), Drafts (`openDraft`), the tab bar (`compose`), links
/// (`openMailto`), and the background tasks (`catchUpOutbox`, `outboxDeadline`). The rest
/// is in `AppModel+Compose` and `AppModel+Sending`.
extension AppModel {
    // MARK: Opening the composer

    /// A new, empty message from the account shown, with its default signature.
    func compose() async {
        guard let from = defaultFrom else { return }
        let composer = Composer(kind: .new, from: from)
        composer.signature = await defaultSignature(for: from)
        present(composer)
    }

    /// Answers a thread's latest message: who it goes to, the subject, the quote, a
    /// forward's files and the account's default signature come from the engine. The
    /// composer opens once they are there; a failure shows in an alert.
    func startAnswer(_ answer: Answer, to thread: MailThread.ID) async {
        let date = self.thread(thread)?.latest?.date ?? self.thread(thread)?.date ?? clock.now()
        let dateText = date.formatted(date: .abbreviated, time: .shortened)
        let started = await engine(for: thread.account, report: true) {
            try $0.startAnswer(accountId: thread.account, threadId: thread.thread, kind: answer.kind, dateText: dateText)
        }
        guard let started else { return }
        let composer = Composer(kind: answer.composerKind, from: thread.account)
        composer.to = started.to
        // Reply-all keeps who was on Cc, and on the account's own message who was on Bcc.
        composer.cc = started.cc
        composer.bcc = started.bcc
        composer.showsCcBcc = !started.cc.isEmpty || !started.bcc.isEmpty
        composer.subject = started.subject
        composer.quoted = started.quoted
        composer.kept = started.kept
        composer.reply = started.reply
        composer.signature = started.signature.map { Composer.Signature(id: $0.id, html: $0.html) }
        present(composer)
    }

    /// Opens the draft in a Drafts thread to go on writing it.
    func openDraft(thread: MailThread.ID) async {
        let draft = await engine(for: thread.account, report: true) {
            try $0.draftForThread(accountId: thread.account, threadId: thread.thread)
        }
        guard let draft else { return }
        reached(thread.account)
        let composer = Composer(draft: draft, from: thread.account)
        if let signature = composer.signature {
            // Its id, when it is one of the account's signatures as they are now.
            let known = await signatures(for: thread.account)
            composer.signature?.id = known.first { $0.html == signature.html }?.id
        }
        present(composer)
    }

    /// A `mailto:` link as a new message. False when it is not one, or there is no account
    /// to write from yet.
    @discardableResult
    func openMailto(_ url: URL) -> Bool {
        guard phase == .signedIn, let from = defaultFrom,
              let mailto = parseMailto(link: url.absoluteString) else { return false }
        let composer = Composer(mailto: mailto, from: from)
        present(composer)
        Task {
            let signature = await defaultSignature(for: from)
            if composer.signature == nil, composer.from == from { composer.signature = signature }
        }
        return true
    }

    /// Leaving a mailing list by mail, as the Mac does: a prepared message to the list's
    /// address, from the account the mail came to, with exactly the subject and text the
    /// list asked for and no signature (a program reads it). It opens in the composer for
    /// the person to send; never into a message being written, which would gain the list
    /// as a recipient.
    func startUnsubscribe(to: String, subject: String, body: String, account: Account.ID) async {
        if composer != nil {
            show(Toast(icon: .alert, text: String(localized: "Finish or close what you are writing, then tap Unsubscribe again."), duration: Toast.telling))
            return
        }
        let composer = Composer(kind: .new, from: account)
        composer.to = Recipients.chips(to)
        composer.subject = subject
        composer.text = body
        composer.written = body.isEmpty ? "<div><br></div>" : textToHtml(text: body)
        composer.signature = nil
        present(composer)
    }

    // MARK: The outbox, for the background tasks

    /// Catches every account up: what an earlier run left (`unsent`), Send later that is
    /// due (`sendDue`), then what waited for the connection (`catchUp`). Safe to call
    /// often: from the foreground, from a background task, when back online.
    func catchUpOutbox() async {
        guard phase == .signedIn else { return }
        for account in accounts.map(\.id) {
            await pickUpUnsent(account)
            let sent = await engine(for: account) { try $0.sendDue(accountId: account) } ?? []
            if !sent.isEmpty {
                show(Toast(icon: .send, text: sent.count == 1
                    ? String(localized: "A scheduled message was sent.")
                    : String(localized: "\(sent.count) scheduled messages were sent.")))
            }
            await loadPendingWork(account)
            await loadScheduled(account)
            guard waitingMessages[account, default: 0] > 0 || queuedChanges[account, default: 0] > 0 else { continue }
            guard let done = await engine(for: account, work: { try $0.catchUp(accountId: account) }) else { continue }
            reached(account)
            await loadPendingWork(account)
            if done.done || done.sent > 0 || !done.movedToDrafts.isEmpty {
                show(Toast(icon: .send, text: Self.backOnline(done), duration: Toast.telling))
            }
        }
    }

    /// The soonest time anything waits for: a send later, or the next retry while a
    /// message waits for the connection. For a background task's earliest begin date.
    func outboxDeadline() async -> Date? {
        var soonest: Int64?
        for account in accounts.map(\.id) {
            let work = await engine(for: account) { try $0.pendingWork(accountId: account) }
            if let next = work?.nextDeadlineMs { soonest = min(soonest ?? next, next) }
        }
        return soonest.map(Date.init(milliseconds:))
    }

}
