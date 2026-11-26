import Foundation

/// A conversation: what a row in the inbox stands for.
nonisolated struct MailThread: Identifiable, Hashable {
    let id: UUID
    var subject: String
    var messages: [Message]
    var category: SplitCategory
    var labels: [String] = []
    var isUnread = false
    var isStarred = false
    /// Set while snoozed: the thread is out of the inbox until then.
    var snoozedUntil: Date?

    init(subject: String, messages: [Message], category: SplitCategory, labels: [String] = [], isUnread: Bool = false) {
        self.id = UUID()
        self.subject = subject
        self.messages = messages
        self.category = category
        self.labels = labels
        self.isUnread = isUnread
    }

    var latest: Message? { messages.last }

    /// Who the row names: the latest message's sender.
    var sender: Person? { latest?.from }

    var date: Date { latest?.date ?? .distantPast }

    var snippet: String {
        latest?.body.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasSuffix(",") }
            .joined(separator: " ") ?? ""
    }

    /// Everyone on the thread, senders first, once each.
    var participants: [Person] {
        var seen = Set<String>()
        return messages.flatMap { [$0.from] + $0.to }.filter { seen.insert($0.email).inserted }
    }
}
