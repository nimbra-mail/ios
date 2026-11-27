import Foundation
import NimbraCore

nonisolated extension ListingKey {
    /// All inboxes: every account's inbox merged, newest first. No account has an empty id,
    /// so the key never names one; actions on its rows reach it like any listing.
    static let allInboxes = ListingKey(account: "", mailbox: .inbox)
}

/// All inboxes (11 · All inboxes): what the device keeps of every inbox at once, then each
/// account's newest threads fetched side by side, a page more as the list is scrolled.
extension AppModel {
    /// One page of each account's inbox.
    static let allInboxesPage: UInt32 = 30

    var allInboxesListing: Listing? { listings[.allInboxes] }

    /// Unread threads in every inbox.
    var allInboxesUnread: Int {
        accounts.reduce(0) { $0 + inboxUnread($1.id) }
    }

    /// The account a row of All inboxes is from, for its tag.
    func account(_ id: Account.ID) -> Account? {
        accounts.first { $0.id == id }
    }

    /// From the device at once, then up to date.
    func showAllInboxes() async {
        if listings[.allInboxes] == nil {
            let names = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, labelNames($0.id)) })
            if let rows = await engine(work: { try $0.cachedAllInboxes() }) {
                listings[.allInboxes] = Listing(threads: rows.map { Self.thread($0, names: names) })
            }
        }
        await refreshAllInboxes()
    }

    /// Every account's newest inbox threads, as far as the list was scrolled. An account
    /// that cannot be reached is left out; all of them failing is the error. Network.
    func refreshAllInboxes() async {
        guard listings[.allInboxes]?.isRefreshing != true else { return }
        listings[.allInboxes, default: Listing()].isRefreshing = true
        defer { listings[.allInboxes]?.isRefreshing = false }
        let perAccount = allInboxesPerAccount
        guard let page = await engine(work: { try $0.allInboxes(perAccount: perAccount) }) else { return }
        if page.failedAccounts == 0 { isOffline = false }
        let names = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, labelNames($0.id)) })
        var listing = listings[.allInboxes] ?? Listing()
        listing.threads = page.threads.map { Self.thread($0, names: names) }
        // A full page from some account means it may have more.
        let byAccount = Dictionary(grouping: page.threads, by: { $0.accountId ?? "" })
        listing.nextPage = byAccount.values.contains { $0.count >= Int(perAccount) } ? String(perAccount) : nil
        listing.isFresh = true
        listings[.allInboxes] = listing
        for count in page.unread {
            // `labelId` is the account here: each account's unread inbox threads.
            unread[count.labelId, default: [:]]["INBOX"] = Int(count.unread)
        }
    }

    /// The next page of every inbox. Network.
    func loadMoreAllInboxes() async {
        guard let listing = listings[.allInboxes], listing.nextPage != nil, !listing.isLoadingMore else { return }
        listings[.allInboxes]?.isLoadingMore = true
        defer { listings[.allInboxes]?.isLoadingMore = false }
        allInboxesPerAccount += Self.allInboxesPage
        await refreshAllInboxes()
    }

    /// A merged row, in its own account, with that account's label names.
    private static func thread(_ row: NimbraCore.ThreadRow, names: [Account.ID: [String: String]]) -> MailThread {
        let account = row.accountId ?? ""
        return MailThread(row: row, account: account, labelNames: names[account] ?? [:])
    }
}
