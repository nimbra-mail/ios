import Foundation
import NimbraCore

/// 06 · Mailboxes and the mailbox lists (11): the account's mailboxes by section with their
/// counts, the snoozed and reminder times, and what Done means in each mailbox.
extension AppModel {
    /// The account's mailboxes in one section, in the engine's order.
    func mailboxes(_ account: Account.ID?, in section: MailboxSection) -> [MailboxEntry] {
        guard let account else { return [] }
        return (mailboxes[account] ?? []).filter { $0.section == section }
    }

    /// What a mailbox's row counts, as the Mac's sidebar does: unread in the inbox, its
    /// categories, Important and labels; all of Drafts; the snoozed threads and reminders.
    /// Zero shows nothing.
    func count(_ mailbox: Mailbox, in account: Account.ID) -> Int {
        switch mailbox {
        case .snoozed: return snoozes[account]?.count { !$0.onlyIfNoReply } ?? 0
        case .reminders: return snoozes[account]?.count(where: \.onlyIfNoReply) ?? 0
        default:
            guard let (label, isUnread) = mailbox.countedLabel else { return 0 }
            return (isUnread ? unread[account]?[label] : totals[account]?[label]) ?? 0
        }
    }

    /// What Mailboxes shows of an account: its mailboxes, counts and snoozes as kept, then
    /// the labels and counts from the server. Disk, then network.
    func showMailboxes(_ account: Account.ID) async {
        await loadSnoozes(account)
        await refreshLabels(account)
        await refreshCounts(account)
    }

    /// The account's snoozes and reminders, as the engine keeps them. Disk.
    func loadSnoozes(_ account: Account.ID) async {
        if let list = await engine(for: account, work: { try $0.snoozed(accountId: account) }) {
            snoozes[account] = list
        }
    }

    /// The counts Mailboxes shows, from the server (what was kept when it cannot be
    /// reached). Network.
    func refreshCounts(_ account: Account.ID) async {
        let labelIDs = mailboxes[account, default: []].compactMap { $0.mailbox.countedLabel?.id }
        let counts = await engine(for: account) { engine in
            try (try? engine.counts(accountId: account, labelIds: labelIDs)) ?? engine.cachedCounts(accountId: account)
        }
        guard let counts else { return }
        var byLabel = unread[account] ?? [:]
        var total = totals[account] ?? [:]
        for count in counts {
            byLabel[count.labelId] = Int(count.unread)
            total[count.labelId] = Int(count.total)
        }
        unread[account] = byLabel
        totals[account] = total
    }

    /// When a snoozed thread or reminder comes back.
    func wakeTime(_ id: MailThread.ID) -> Date? {
        snoozes[id.account]?.first { $0.threadId == id.thread }.map { Date(milliseconds: $0.untilMs) }
    }

    /// The listing of a mailbox (All inboxes for `.allInboxes`), from the device and then up
    /// to date.
    func showListing(_ key: ListingKey) async {
        if key == .allInboxes {
            await showAllInboxes()
        } else {
            if key.mailbox == .snoozed || key.mailbox == .reminders { await loadSnoozes(key.account) }
            await show(key)
        }
    }

    func refreshListing(_ key: ListingKey) async {
        if key == .allInboxes { await refreshAllInboxes() } else { await refresh(key) }
    }

    func loadMoreListing(_ key: ListingKey) async {
        if key == .allInboxes { await loadMoreAllInboxes() } else { await loadMore(key) }
    }

    /// Reports a thread as spam. Network.
    func reportSpam(_ id: MailThread.ID) async {
        await act(id, .spam, removes: true)
    }
}
