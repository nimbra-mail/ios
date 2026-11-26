import Foundation
import NimbraCore

/// What a person does to a thread: read, star, Done, snooze. Each shows at once and goes
/// to the engine, which queues it while offline; a refusal puts the listing back as it
/// was and says why.
extension AppModel {
    func markRead(_ id: MailThread.ID) async {
        guard thread(id)?.isUnread == true else { return }
        await act(id, .markRead) { $0.isUnread = false }
    }

    func markUnread(_ id: MailThread.ID) async {
        await act(id, .markUnread) { $0.isUnread = true }
    }

    func toggleStar(_ id: MailThread.ID) async {
        let starred = thread(id)?.isStarred ?? false
        await act(id, starred ? .unstar : .star) { $0.isStarred = !starred }
    }

    /// Done: out of the inbox (archived).
    func markDone(_ id: MailThread.ID) async {
        await act(id, .done, removes: true)
    }

    /// Marks every unread thread listed in the inbox as read.
    func markAllRead() async {
        for thread in inboxThreads where thread.isUnread {
            await markRead(thread.id)
        }
    }

    /// Puts a thread away until `date`; a reminder (`onlyIfNoReply`) brings it back only
    /// if nobody replied by then.
    func snooze(_ id: MailThread.ID, until date: Date, onlyIfNoReply: Bool = false) async {
        let before = listings
        remove(id)
        let done: Void? = await engine(for: id.account, report: true) {
            try $0.snooze(accountId: id.account, threadId: id.thread, untilMs: date.milliseconds, onlyIfNoReply: onlyIfNoReply)
        }
        if done == nil { listings = before }
        await loadSnoozed(id.account)
    }

    /// A thread wherever it is shown: opened, listed, snoozed or found.
    func thread(_ id: MailThread.ID) -> MailThread? {
        if let thread = opened[id] { return thread }
        for listing in listings.values {
            if let thread = listing.threads.first(where: { $0.id == id }) { return thread }
        }
        return snoozedThreads[id.account]?.first { $0.id == id } ?? searchResults.first { $0.id == id }
    }

    /// Applies `action`: `change` (or taking the thread out) shows at once, and is undone
    /// when the engine refuses it.
    private func act(_ id: MailThread.ID, _ action: ThreadAction, removes: Bool = false, change: (inout MailThread) -> Void = { _ in }) async {
        let before = (listings, opened, searchResults)
        if removes { remove(id) } else { update(id, change) }
        let outcome = await engine(for: id.account, report: true) {
            try $0.apply(accountId: id.account, threadId: id.thread, action: action)
        }
        switch outcome {
        case nil: (listings, opened, searchResults) = before
        case .done: reached(id.account)
        // Offline: it waits on the device and is made once the server can be reached.
        case .queued: isOffline = true
        }
        // The counts follow the server's; queued offline, they catch up on the next refresh.
        if outcome == .done, action == .markRead || action == .markUnread || removes {
            await loadCachedCounts(id.account)
        }
    }

    /// Changes a thread everywhere it is shown.
    func update(_ id: MailThread.ID, _ change: (inout MailThread) -> Void) {
        for key in listings.keys where key.account == id.account {
            if let index = listings[key]?.threads.firstIndex(where: { $0.id == id }) {
                change(&listings[key]!.threads[index])
            }
        }
        if opened[id] != nil { change(&opened[id]!) }
        if let index = searchResults.firstIndex(where: { $0.id == id }) { change(&searchResults[index]) }
    }

    /// Takes a thread out of every listing (Done, snoozed).
    func remove(_ id: MailThread.ID) {
        for key in listings.keys where key.account == id.account {
            listings[key]?.threads.removeAll { $0.id == id }
        }
        opened[id] = nil
        searchResults.removeAll { $0.id == id }
    }
}
