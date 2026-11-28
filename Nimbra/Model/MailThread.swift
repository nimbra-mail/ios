import Foundation
import NimbraCore

/// A conversation: what a row in a mailbox stands for. Listings carry its summary; its
/// messages come once it is read (`AppModel.loadMessages`).
nonisolated struct MailThread: Identifiable, Hashable, Sendable {
    /// A thread's id is its account's own: the account tells two apart.
    nonisolated struct ID: Hashable, Sendable {
        let account: Account.ID
        let thread: String
    }

    let id: ID
    var subject: String
    /// Who the row names: the latest message's sender.
    var sender: Person?
    var snippet: String
    var date: Date
    var messageCount: Int
    /// Its labels' names (the account's own labels; not Inbox, Starred and the like).
    var labels: [String]
    var isUnread: Bool
    var isStarred: Bool
    /// Set while snoozed: the thread is out of the inbox until then.
    var snoozedUntil: Date?
    /// Its messages, oldest first, once read. Empty in a listing.
    var messages: [Message]

    init(
        id: ID, subject: String, sender: Person?, snippet: String, date: Date, messageCount: Int,
        labels: [String] = [], isUnread: Bool = false, isStarred: Bool = false,
        snoozedUntil: Date? = nil, messages: [Message] = []
    ) {
        self.id = id
        self.subject = subject
        self.sender = sender
        self.snippet = snippet
        self.date = date
        self.messageCount = messageCount
        self.labels = labels
        self.isUnread = isUnread
        self.isStarred = isStarred
        self.snoozedUntil = snoozedUntil
        self.messages = messages
    }

    /// A thread from its messages (sample mail): the row's summary comes from the latest.
    init(id: ID, subject: String, messages: [Message], labels: [String] = [], isUnread: Bool = false) {
        let latest = messages.last
        self.init(
            id: id, subject: subject, sender: latest?.from, snippet: latest?.summary ?? "",
            date: latest?.date ?? .distantPast, messageCount: messages.count, labels: labels,
            isUnread: isUnread, messages: messages
        )
    }

    /// An engine row in `account`. `labelNames` names the account's labels by id; the
    /// labels it does not name (Inbox, the categories) are left out.
    init(row: NimbraCore.ThreadRow, account: Account.ID, labelNames: [String: String] = [:]) {
        self.init(
            id: ID(account: row.accountId ?? account, thread: row.id),
            subject: row.subject,
            sender: Person(name: row.sender, email: row.senderAddress ?? ""),
            snippet: row.snippet,
            date: Date(milliseconds: row.timestampMs),
            messageCount: Int(row.messageCount),
            labels: row.labels.compactMap { labelNames[$0] },
            isUnread: row.unread,
            isStarred: row.starred
        )
    }

    var latest: Message? { messages.last }

    /// Everyone on the thread, senders first, once each; the sender alone until it is read.
    var participants: [Person] {
        guard !messages.isEmpty else { return sender.map { [$0] } ?? [] }
        var seen = Set<String>()
        return (messages.map(\.from) + messages.flatMap(\.recipients)).filter { seen.insert($0.email).inserted }
    }
}

extension Date {
    /// A time from the engine (milliseconds since 1970).
    nonisolated init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }

    /// The time as the engine takes it.
    nonisolated var milliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }
}
