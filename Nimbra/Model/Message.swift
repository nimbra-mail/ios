import Foundation

/// One message in a thread.
nonisolated struct Message: Identifiable, Hashable {
    let id: UUID
    let from: Person
    let to: [Person]
    let date: Date
    let body: String
    var attachments: [Attachment] = []

    init(from: Person, to: [Person], date: Date, body: String, attachments: [Attachment] = []) {
        self.id = UUID()
        self.from = from
        self.to = to
        self.date = date
        self.body = body
        self.attachments = attachments
    }

    /// The first line with words in it, for a folded message.
    var preview: String {
        body.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasSuffix(",") } ?? ""
    }
}

/// A file sent with a message.
nonisolated struct Attachment: Hashable {
    let name: String
    let kind: String
    let size: Measurement<UnitInformationStorage>
}
