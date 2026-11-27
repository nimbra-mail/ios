import Foundation
import NimbraCore
import UIKit

/// A snooze as it was made: the thread, when it comes back, and the listings it was taken
/// out of, so its Undo puts it back as it was.
nonisolated struct SnoozeUndo: Equatable, Sendable {
    let thread: MailThread
    let until: Date
    let onlyIfNoReply: Bool
    /// The listings it was in, and where.
    let places: [ListingKey: Int]
}

/// Snoozing: a thread put away until a time (or, as a reminder, until then if nobody
/// replied), Undo, and the snoozes' exact return notifications kept in step.
extension AppModel {
    /// Puts a thread away until `date`; a reminder (`onlyIfNoReply`) brings it back only
    /// if nobody replied by then. It leaves the listings at once, and a toast offers Undo.
    /// What Undo needs, when it was snoozed.
    @discardableResult
    func snooze(_ id: MailThread.ID, until date: Date, onlyIfNoReply: Bool = false) async -> SnoozeUndo? {
        let shown = thread(id)
        let before = listings
        var places: [ListingKey: Int] = [:]
        for (key, listing) in listings where key.account == id.account {
            if let index = listing.threads.firstIndex(where: { $0.id == id }) { places[key] = index }
        }
        remove(id)
        let done: Void? = await engine(for: id.account, report: true) {
            try $0.snooze(accountId: id.account, threadId: id.thread, untilMs: date.milliseconds, onlyIfNoReply: onlyIfNoReply)
        }
        guard done != nil else {
            listings = before
            return nil
        }
        await loadSnoozed(id.account)
        await scheduleSnoozeReturns()
        guard let shown else { return nil }
        let undo = SnoozeUndo(thread: shown, until: date, onlyIfNoReply: onlyIfNoReply, places: places)
        let when = SnoozeTimeText.hint(date, now: clock())
        let text = onlyIfNoReply
            ? String(localized: "Reminder for \(when) if nobody replies")
            : String(localized: "Snoozed until \(when)")
        // Longer with VoiceOver on, so there is time to reach Undo.
        let duration: Duration = UIAccessibility.isVoiceOverRunning ? .seconds(12) : .seconds(4)
        show(Toast(icon: onlyIfNoReply ? .bell : .clock, text: text, duration: duration)) { [weak self] in
            await self?.undoSnooze(undo)
        }
        return undo
    }

    /// Undo of a snooze: cancelled, and the thread back where it was listed.
    func undoSnooze(_ undo: SnoozeUndo) async {
        await unsnooze(undo.thread.id, putBack: undo)
    }

    /// Cancels a snooze or a reminder: the thread back in the inbox now. Network.
    func unsnooze(_ id: MailThread.ID) async {
        await unsnooze(id, putBack: nil)
    }

    private func unsnooze(_ id: MailThread.ID, putBack undo: SnoozeUndo?) async {
        let done: Void? = await engine(for: id.account, report: true) {
            try $0.unsnooze(accountId: id.account, threadId: id.thread)
        }
        guard done != nil else { return }
        reached(id.account)
        if let undo {
            for (key, index) in undo.places where listings[key] != nil {
                guard listings[key]?.threads.contains(where: { $0.id == id }) == false else { continue }
                let at = min(index, listings[key]?.threads.count ?? 0)
                listings[key]?.threads.insert(undo.thread, at: at)
            }
        }
        await loadSnoozed(id.account)
        await scheduleSnoozeReturns()
        if undo == nil, let key = inboxKey, key.account == id.account {
            await refresh(key)
        }
    }
}
