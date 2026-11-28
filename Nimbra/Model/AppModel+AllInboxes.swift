import Foundation
import NimbraCore

nonisolated extension ListingKey {
    /// Every account's `mailbox` merged, newest first (All inboxes is the inbox's). No
    /// account has an empty id, so the key never names one; actions on its rows reach it
    /// like any listing.
    static func every(_ mailbox: Mailbox) -> ListingKey {
        ListingKey(account: "", mailbox: mailbox)
    }

    /// All inboxes: every account's inbox merged, newest first.
    static let allInboxes = every(.inbox)

    /// A list of every account's mailbox (All inboxes, or Starred, Sent… of every account).
    var isEveryAccount: Bool { account.isEmpty }
}

/// All inboxes (11 · All inboxes) and every account's other mailboxes (06 · Mailboxes ·
/// Every account): what the device keeps of each account's mailbox at once, then each
/// account's newest threads fetched side by side, a page more as the list is scrolled.
extension AppModel {
    /// One page of each account's mailbox.
    static let allInboxesPage: UInt32 = 30

    /// The mailboxes Mailboxes lists for every account at once, as the Mac's sidebar does
    /// under All inboxes.
    static let everyAccountMailboxes: [Mailbox] = [.starred, .important, .snoozed, .reminders, .drafts, .sent, .spam, .trash]

    var allInboxesListing: Listing? { listings[.allInboxes] }

    /// Unread threads in every inbox.
    var allInboxesUnread: Int {
        accounts.reduce(0) { $0 + inboxUnread($1.id) }
    }

    /// What an every-account mailbox's row counts: each account's count added up.
    func everyCount(_ mailbox: Mailbox) -> Int {
        accounts.reduce(0) { $0 + count(mailbox, in: $1.id) }
    }

    /// The every-account mailboxes Mailboxes lists: Important only while some account has
    /// it (Gmail's own).
    var everyAccountMailboxes: [Mailbox] {
        let hasImportant = accounts.contains { $0.kind == .gmail }
        return Self.everyAccountMailboxes.filter { $0 != .important || hasImportant }
    }

    /// The account a row of All inboxes is from, for its tag.
    func account(_ id: Account.ID) -> Account? {
        accounts.first { $0.id == id }
    }

    /// All inboxes, from the device at once, then up to date.
    func showAllInboxes() async {
        await showEvery(.inbox)
    }

    /// Every account's `mailbox`, from the device at once, then up to date.
    func showEvery(_ mailbox: Mailbox) async {
        let key = ListingKey.every(mailbox)
        if listings[key] == nil {
            let names = labelNamesByAccount
            // All inboxes is the engine's every inbox; its own call says so.
            if let rows = await engine(work: { try mailbox == .inbox ? $0.cachedAllInboxes() : $0.cachedEveryMailbox(mailbox: mailbox) }) {
                listings[key] = Listing(threads: rows.map { Self.thread($0, names: names) })
            }
        }
        if mailbox == .snoozed || mailbox == .reminders {
            for account in accounts { await loadSnoozes(account.id) }
        }
        await refreshEvery(mailbox)
    }

    func refreshAllInboxes() async {
        await refreshEvery(.inbox)
    }

    /// Every account's newest threads of `mailbox`, as far as the list was scrolled. An
    /// account that cannot be reached is left out; all of them failing is the error.
    /// Network.
    func refreshEvery(_ mailbox: Mailbox) async {
        let key = ListingKey.every(mailbox)
        guard listings[key]?.isRefreshing != true else { return }
        listings[key, default: Listing()].isRefreshing = true
        defer { listings[key]?.isRefreshing = false }
        let perAccount = everyPerAccount[mailbox] ?? Self.allInboxesPage
        guard let page = await engine(work: {
            try mailbox == .inbox ? $0.allInboxes(perAccount: perAccount) : $0.everyMailbox(mailbox: mailbox, perAccount: perAccount)
        }) else { return }
        if page.failedAccounts == 0 { isOffline = false }
        let names = labelNamesByAccount
        var listing = listings[key] ?? Listing()
        listing.threads = page.threads.map { Self.thread($0, names: names) }
        // A full page from some account means it may have more.
        let byAccount = Dictionary(grouping: page.threads, by: { $0.accountId ?? "" })
        listing.nextPage = byAccount.values.contains { $0.count >= Int(perAccount) } ? String(perAccount) : nil
        listing.isFresh = true
        listings[key] = listing
        // `labelId` is the account here: each account's count of the mailbox.
        if mailbox == .inbox {
            for count in page.unread {
                unread[count.labelId, default: [:]]["INBOX"] = Int(count.unread)
            }
        }
    }

    func loadMoreAllInboxes() async {
        await loadMoreEvery(.inbox)
    }

    /// The next page of every account's `mailbox`. Network.
    func loadMoreEvery(_ mailbox: Mailbox) async {
        let key = ListingKey.every(mailbox)
        guard let listing = listings[key], listing.nextPage != nil, !listing.isLoadingMore else { return }
        listings[key]?.isLoadingMore = true
        defer { listings[key]?.isLoadingMore = false }
        everyPerAccount[mailbox, default: Self.allInboxesPage] += Self.allInboxesPage
        await refreshEvery(mailbox)
    }

    /// Each account's label names, by account.
    private var labelNamesByAccount: [Account.ID: [String: String]] {
        Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, labelNames($0.id)) })
    }

    /// A merged row, in its own account, with that account's label names.
    private static func thread(_ row: NimbraCore.ThreadRow, names: [Account.ID: [String: String]]) -> MailThread {
        let account = row.accountId ?? ""
        return MailThread(row: row, account: account, labelNames: names[account] ?? [:])
    }
}
