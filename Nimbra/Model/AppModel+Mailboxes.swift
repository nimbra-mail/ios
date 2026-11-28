import Foundation
import NimbraCore

/// Mailboxes and the inbox: what the device keeps comes first, at once and offline, then
/// the server's changes (`refresh`), then more pages as the list is scrolled (`loadMore`).
extension AppModel {
    /// Whether the account has the split inbox (Gmail's categories), as the engine lists
    /// its mailboxes. Accounts with their own servers have one inbox.
    func hasSplitInbox(_ account: Account.ID?) -> Bool {
        guard let account else { return false }
        return mailboxes[account]?.contains { $0.section == .split } ?? false
    }

    /// The mailbox the Inbox tab lists: the category picked, or the whole inbox.
    var inboxMailbox: Mailbox {
        hasSplitInbox(accountID) ? split?.mailbox ?? .inbox : .inbox
    }

    var inboxKey: ListingKey? {
        accountID.map { ListingKey(account: $0, mailbox: inboxMailbox) }
    }

    /// The inbox's threads, newest first.
    var inboxThreads: [MailThread] {
        inboxKey.flatMap { listings[$0]?.threads } ?? []
    }

    var inboxListing: Listing? {
        inboxKey.flatMap { listings[$0] }
    }

    /// Unread threads in a split inbox category of the account shown, or (nil) in its
    /// whole inbox.
    func unreadCount(_ category: SplitCategory?) -> Int {
        guard let accountID else { return 0 }
        return unread[accountID]?[category?.labelID ?? "INBOX"] ?? 0
    }

    /// Unread threads in an account's inbox.
    func inboxUnread(_ account: Account.ID) -> Int {
        unread[account]?["INBOX"] ?? 0
    }

    /// Snoozed threads and reminders of the account shown.
    var snoozed: [MailThread] {
        accountID.flatMap { snoozedThreads[$0] } ?? []
    }

    /// Shows a split inbox category, or (nil) the whole inbox.
    func selectSplit(_ category: SplitCategory?) async {
        guard category != split else { return }
        split = category
        await showInbox()
    }

    /// The inbox of the account shown: from the device, then up to date.
    func showInbox() async {
        guard let key = inboxKey else { return }
        lastShown = key
        await show(key)
        await loadSnoozed(key.account)
    }

    /// A mailbox: what the device keeps at once, then brought up to date.
    func show(_ key: ListingKey) async {
        if listings[key] == nil { await loadCached(key) }
        await refresh(key)
    }

    /// A mailbox as kept on the device. Disk.
    func loadCached(_ key: ListingKey) async {
        let names = labelNames(key.account)
        guard let rows = await engine(for: key.account, work: { try $0.cachedThreads(accountId: key.account, mailbox: key.mailbox) }) else { return }
        var listing = listings[key] ?? Listing()
        listing.threads = rows.map { MailThread(row: $0, account: key.account, labelNames: names) }
        listings[key] = listing
    }

    /// Brings a mailbox up to date with the server and lists it from the device again,
    /// with the account's counts and labels. Network.
    func refresh(_ key: ListingKey) async {
        guard listings[key]?.isRefreshing != true else { return }
        listings[key, default: Listing()].isRefreshing = true
        defer { listings[key]?.isRefreshing = false }

        let labelIDs = countedLabels(key.account)
        let fetched = await engine(for: key.account) { engine -> (ThreadPage, [NimbraCore.ThreadRow], [MailboxEntry], [LabelCount]) in
            let page: ThreadPage
            do {
                page = try engine.refreshMailbox(accountId: key.account, mailbox: key.mailbox)
            } catch NimbraError.HistoryExpired {
                // The change feed was too old: the engine lists it afresh on the next try.
                page = try engine.refreshMailbox(accountId: key.account, mailbox: key.mailbox)
            }
            let rows = try engine.cachedThreads(accountId: key.account, mailbox: key.mailbox)
            let boxes = try engine.mailboxes(accountId: key.account)
            // The server's counts; what was kept when they cannot be fetched.
            let counts = try (try? engine.counts(accountId: key.account, labelIds: labelIDs))
                ?? engine.cachedCounts(accountId: key.account)
            return (page, rows, boxes, counts)
        }
        guard let (page, rows, boxes, counts) = fetched else { return }
        reached(key.account)
        mailboxes[key.account] = boxes
        setCounts(counts, for: key.account)
        let names = labelNames(key.account)
        var listing = listings[key] ?? Listing()
        listing.threads = rows.map { MailThread(row: $0, account: key.account, labelNames: names) }
        if !listing.isFresh || listing.nextPage == nil { listing.nextPage = page.nextPage }
        listing.isFresh = true
        listings[key] = listing
    }

    /// The next page of a mailbox, kept after what is listed. Network.
    func loadMore(_ key: ListingKey) async {
        guard let listing = listings[key], let page = listing.nextPage, !listing.isLoadingMore else { return }
        listings[key]?.isLoadingMore = true
        defer { listings[key]?.isLoadingMore = false }
        guard let more = await engine(for: key.account, work: { try $0.loadMore(accountId: key.account, mailbox: key.mailbox, page: page) }) else { return }
        reached(key.account)
        let names = labelNames(key.account)
        var threads = listings[key]?.threads ?? []
        let known = Set(threads.map(\.id))
        threads += more.threads.map { MailThread(row: $0, account: key.account, labelNames: names) }.filter { !known.contains($0.id) }
        listings[key]?.threads = threads
        listings[key]?.nextPage = more.nextPage
    }

    /// The inbox's next page.
    func loadMoreInbox() async {
        guard let key = inboxKey else { return }
        await loadMore(key)
    }

    /// An account's mailboxes as last fetched. Disk.
    func loadMailboxes(_ account: Account.ID) async {
        if let boxes = await engine(for: account, work: { try $0.mailboxes(accountId: account) }) {
            mailboxes[account] = boxes
        }
    }

    /// An account's counts as last fetched. Disk.
    func loadCachedCounts(_ account: Account.ID) async {
        if let counts = await engine(for: account, work: { try $0.cachedCounts(accountId: account) }) {
            setCounts(counts, for: account)
        }
    }

    /// The account's snoozed threads and reminders. Disk.
    func loadSnoozed(_ account: Account.ID) async {
        guard let list = await engine(for: account, work: { try $0.snoozed(accountId: account) }) else { return }
        snoozedThreads[account] = list.map { snoozed in
            MailThread(
                id: .init(account: snoozed.accountId ?? account, thread: snoozed.threadId),
                subject: snoozed.subject,
                sender: Person(name: snoozed.sender, email: ""),
                snippet: snoozed.snippet,
                date: Date(milliseconds: snoozed.untilMs),
                messageCount: 1,
                snoozedUntil: Date(milliseconds: snoozed.untilMs)
            )
        }
    }

    // MARK: Helpers

    /// The labels whose counts the app shows: the inbox, the split inbox, and the
    /// account's first labels, as the Mac counts them.
    private func countedLabels(_ account: Account.ID) -> [String] {
        let labels = (mailboxes[account] ?? []).compactMap { entry -> String? in
            if case .label(let id) = entry.mailbox { id } else { nil }
        }
        return ["INBOX"] + (hasSplitInbox(account) ? SplitCategory.allCases.map(\.labelID) : [])
            // Mailboxes: Important's unread and Drafts' total, as 06 · Mailboxes shows them.
            + (hasSplitInbox(account) ? ["IMPORTANT"] : []) + ["DRAFT"]
            + labels.prefix(8)
    }

    /// The account's labels' names, by id.
    func labelNames(_ account: Account.ID) -> [String: String] {
        var names: [String: String] = [:]
        for entry in mailboxes[account] ?? [] {
            if case .label(let id) = entry.mailbox, let name = entry.name { names[id] = name }
        }
        return names
    }

    private func setCounts(_ counts: [LabelCount], for account: Account.ID) {
        var byLabel = unread[account] ?? [:]
        var total = totals[account] ?? [:]
        for count in counts {
            byLabel[count.labelId] = Int(count.unread)
            total[count.labelId] = Int(count.total)
        }
        unread[account] = byLabel
        totals[account] = total
    }
}
