import Foundation
import NimbraCore

/// Search, as the Mac's finder: the account shown, what the device has listed at once, then
/// the server's results (Gmail's search words, or text for an account with its own
/// servers) merged in, a page more as the list is scrolled.
extension AppModel {
    /// The threads listed on the device whose sender, subject or snippet has every word
    /// typed, newest first. Words with a colon (`from:`, `is:unread`) are the server's.
    func localMatches(_ query: String, in account: Account.ID, limit: Int = 8) -> [MailThread] {
        let words = query.split(whereSeparator: \.isWhitespace).filter { !$0.contains(":") }
        guard !words.isEmpty else { return [] }
        var seen = Set<MailThread.ID>()
        let threads = listings
            .filter { $0.key.account == account || $0.key == .allInboxes }
            .flatMap(\.value.threads)
            .filter { $0.id.account == account && seen.insert($0.id).inserted }
        return threads
            .filter { thread in
                let text = [thread.sender?.name ?? "", thread.sender?.email ?? "", thread.subject, thread.snippet].joined(separator: " ")
                return words.allSatisfy { text.localizedStandardContains($0) }
            }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map(\.self)
    }

    /// Searches the account shown: the device's matches at once, then the server's first
    /// page. Network.
    func find(_ query: String) async {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard let account = accountID, !query.isEmpty else {
            searchResults = []
            searchNextPage = nil
            isFinding = false
            return
        }
        let local = localMatches(query, in: account)
        searchResults = local
        searchNextPage = nil
        // One letter is too little to ask the server about.
        guard query.count >= 2 else { return }
        isFinding = true
        defer { isFinding = false }
        let names = labelNames(account)
        guard let page = await engine(for: account, work: { try $0.search(accountId: account, query: query, page: nil, limit: 30) }),
              !Task.isCancelled else { return }
        reached(account)
        let found = page.threads.map { MailThread(row: $0, account: account, labelNames: names) }
        let known = Set(found.map(\.id))
        searchResults = (found + local.filter { !known.contains($0.id) }).sorted { $0.date > $1.date }
        searchNextPage = page.nextPage
    }

    /// The server's next page of results. Network.
    func findMore(_ query: String) async {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard let account = accountID, let next = searchNextPage, !isFinding else { return }
        isFinding = true
        defer { isFinding = false }
        let names = labelNames(account)
        guard let page = await engine(for: account, work: { try $0.search(accountId: account, query: query, page: next, limit: 30) }) else { return }
        let known = Set(searchResults.map(\.id))
        searchResults += page.threads.map { MailThread(row: $0, account: account, labelNames: names) }.filter { !known.contains($0.id) }
        searchNextPage = page.nextPage
    }
}

/// A search tip shown while the search field is empty: what to type, and what it finds.
nonisolated struct SearchTip: Sendable {
    let words: String
    let meaning: LocalizedStringResource

    /// The Mac finder's tips, in its order. The engine understands each of them for every
    /// account: Gmail's own search, or IMAP search criteria (core 0.1.5).
    static let all: [SearchTip] = [
        SearchTip(words: "from:", meaning: "From someone"),
        SearchTip(words: "cc:", meaning: "Copied to someone"),
        SearchTip(words: "bcc:", meaning: "Sent to someone unseen"),
        SearchTip(words: "has:attachment", meaning: "With attachments"),
        SearchTip(words: "is:unread", meaning: "Unread only"),
        SearchTip(words: "newer_than:7d", meaning: "From the last week"),
    ]

    /// What the field holds once the tip is picked: a word that takes a value ends at its
    /// colon, anything else gets a space to type on.
    var query: String { words + (words.hasSuffix(":") ? "" : " ") }
}
