import Foundation
import NimbraCore

/// A local notification as Nimbra shows it, before it becomes a `UNNotificationRequest`:
/// what it says and when, decided here so the rules are tested without the system.
///
/// Ids follow the Mac's (`notify.rs`): `acct:<account>:<thread>`, and `acct:<account>:more`
/// for the summary of the rest. A thread therefore never stacks up twice, and a snooze's
/// return replaces the new-mail notification of the same thread.
nonisolated struct MailNotification: Equatable, Sendable {
    let id: String
    let account: Account.ID
    /// The thread it opens; nil for the summary.
    let thread: String?
    let title: String
    var subtitle = ""
    let body: String
    /// Plays Nimbra's mail sound (Preferences).
    let sound: Bool
    /// When it shows: now when nil (new mail), else the snooze's return.
    var fireDate: Date?

    /// A thread's notification has Done and Mark as read; the summary has none.
    var hasActions: Bool { thread != nil }
    /// Grouped by account in Notification Center, as on the Mac.
    var group: String { "acct:\(account)" }

    static func id(account: Account.ID, thread: String) -> String { "acct:\(account):\(thread)" }

    /// The account and thread an id is about; the thread is nil for the summary.
    static func parse(_ id: String) -> (account: Account.ID, thread: String?)? {
        guard id.hasPrefix("acct:") else { return nil }
        let rest = id.dropFirst(5)
        guard let colon = rest.firstIndex(of: ":") else { return nil }
        let account = String(rest[..<colon])
        let thread = String(rest[rest.index(after: colon)...])
        guard !account.isEmpty, !thread.isEmpty else { return nil }
        return (account, thread == summaryThread ? nil : thread)
    }

    private static let summaryThread = "more"

    // MARK: Rules

    /// New mail from `check_for_changes`, as the Mac shows it: nothing when notifications
    /// are off (`notify`) or the account's switch is off; one notification for each thread
    /// the engine names (the first few, blocked senders already left out), then one that
    /// counts the rest. Sender, subject and the snippet, as the lock screen in Figma shows.
    static func newMail(_ result: SyncResult, account: Account.ID, muted: Bool, sound: Bool) -> [MailNotification] {
        guard result.notify, !muted else { return [] }
        var notes = result.named.map { row in
            let owner = row.accountId ?? account
            return MailNotification(
                id: id(account: owner, thread: row.id), account: owner, thread: row.id,
                title: row.sender, subtitle: row.subject, body: row.snippet, sound: sound
            )
        }
        if result.moreNew > 0 {
            notes.append(MailNotification(
                id: "acct:\(account):\(summaryThread)", account: account, thread: nil,
                title: String(localized: "Nimbra"),
                body: String(AttributedString(localized: "^[\(Int(result.moreNew)) more new message](inflect: true)").characters),
                sound: sound
            ))
        }
        return notes
    }

    /// A snooze or a reminder coming back: "Back from snooze", or "No reply yet" for a
    /// reminder, over the subject (the Mac's words). `at` schedules it for its time.
    static func snoozeReturn(_ snoozed: SnoozedThread, account: Account.ID, sound: Bool, at fireDate: Date? = nil) -> MailNotification {
        let owner = snoozed.accountId ?? account
        return MailNotification(
            id: id(account: owner, thread: snoozed.threadId), account: owner, thread: snoozed.threadId,
            title: snoozed.onlyIfNoReply ? String(localized: "No reply yet") : String(localized: "Back from snooze"),
            body: snoozed.subject, sound: sound, fireDate: fireDate
        )
    }

    /// The snoozes' returns to schedule now: those still ahead, of accounts whose switch is
    /// on, the soonest first and at most `limit` of them (iOS keeps 64 waiting).
    static func returns(
        _ snoozed: [(account: Account.ID, thread: SnoozedThread)], now: Date, muted: Set<Account.ID>, sound: Bool, limit: Int = 64
    ) -> [MailNotification] {
        snoozed
            .filter { Date(milliseconds: $0.thread.untilMs) > now && !muted.contains($0.thread.accountId ?? $0.account) }
            .sorted { $0.thread.untilMs < $1.thread.untilMs }
            .prefix(limit)
            .map { snoozeReturn($0.thread, account: $0.account, sound: sound, at: Date(milliseconds: $0.thread.untilMs)) }
    }
}
