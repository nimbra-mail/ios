import Foundation
import Observation

/// The app's state: who is signed in, and the mail. Sample data for now; the
/// mail stays on the device once accounts sign in for real.
@Observable
final class AppModel {
    enum Phase { case welcome, signedIn }

    var phase: Phase
    var accounts: [Account]
    var threads: [MailThread]
    var split: SplitCategory = .important
    /// The account the inbox shows.
    var accountID: Account.ID?
    var isSearching = false

    init(phase: Phase = .welcome, accounts: [Account] = SampleData.accounts, threads: [MailThread] = SampleData.threads()) {
        self.phase = phase
        self.accounts = accounts
        self.threads = threads
        self.accountID = accounts.first?.id
    }

    var account: Account? { accounts.first { $0.id == accountID } }

    // MARK: - Reading

    /// The inbox for a split category: not snoozed, newest first.
    func inbox(_ category: SplitCategory) -> [MailThread] {
        threads.filter { $0.category == category && $0.snoozedUntil == nil }
            .sorted { $0.date > $1.date }
    }

    func unreadCount(_ category: SplitCategory) -> Int {
        inbox(category).count(where: \.isUnread)
    }

    var snoozed: [MailThread] {
        threads.filter { $0.snoozedUntil != nil }
            .sorted { ($0.snoozedUntil ?? .distantFuture) < ($1.snoozedUntil ?? .distantFuture) }
    }

    /// Threads with every word of `query` in their sender, subject or text.
    func search(_ query: String) -> [MailThread] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return [] }
        return threads.filter { thread in
            let haystack = ([thread.subject] + thread.messages.flatMap { [$0.from.name, $0.from.email, $0.body] })
                .joined(separator: " ").lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
        .sorted { $0.date > $1.date }
    }

    func thread(_ id: MailThread.ID) -> MailThread? {
        threads.first { $0.id == id }
    }

    // MARK: - Acting

    func signIn() { phase = .signedIn }

    func markRead(_ id: MailThread.ID) {
        update(id) { $0.isUnread = false }
    }

    func markUnread(_ id: MailThread.ID) {
        update(id) { $0.isUnread = true }
    }

    func markAllRead(_ category: SplitCategory) {
        for index in threads.indices where threads[index].category == category {
            threads[index].isUnread = false
        }
    }

    func toggleStar(_ id: MailThread.ID) {
        update(id) { $0.isStarred.toggle() }
    }

    /// Done: out of the inbox (archived).
    func markDone(_ id: MailThread.ID) {
        threads.removeAll { $0.id == id }
    }

    func snooze(_ id: MailThread.ID, until date: Date) {
        update(id) { $0.snoozedUntil = date }
    }

    private func update(_ id: MailThread.ID, _ change: (inout MailThread) -> Void) {
        guard let index = threads.firstIndex(where: { $0.id == id }) else { return }
        change(&threads[index])
    }
}
