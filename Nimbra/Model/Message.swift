import Foundation
import NimbraCore

/// One message in a thread.
nonisolated struct Message: Identifiable, Hashable, Sendable {
    let id: String
    let from: Person
    let to: [Person]
    let date: Date
    let body: String
    var attachments: [Attachment] = []

    init(id: String = UUID().uuidString, from: Person, to: [Person], date: Date, body: String, attachments: [Attachment] = []) {
        self.id = id
        self.from = from
        self.to = to
        self.date = date
        self.body = body
        self.attachments = attachments
    }

    /// A message as the engine parsed it: its plain text, and its files.
    init(_ message: MailMessage) {
        self.init(
            id: message.messageId.isEmpty ? UUID().uuidString : message.messageId,
            from: Person(message.from),
            to: (message.to + message.cc).map(Person.init),
            date: Date(milliseconds: message.timestampMs),
            body: message.text,
            attachments: message.attachments.map(Attachment.init)
        )
    }

    /// The first line with words in it, for a folded message.
    var preview: String {
        lines.first ?? ""
    }

    /// Its lines with words in them, run together, without the greeting: a row's snippet.
    var summary: String {
        lines.joined(separator: " ")
    }

    private var lines: [String] {
        body.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasSuffix(",") }
    }
}

/// A file sent with a message.
nonisolated struct Attachment: Hashable, Sendable {
    let name: String
    let kind: String
    let size: Measurement<UnitInformationStorage>

    init(name: String, kind: String, size: Measurement<UnitInformationStorage>) {
        self.name = name
        self.kind = kind
        self.size = size
    }

    /// The engine's file: its kind is its extension ("PDF"), else what its type says.
    init(_ info: AttachmentInfo) {
        let ext = (info.name as NSString).pathExtension
        let kind = ext.isEmpty ? (info.mime.split(separator: "/").last.map(String.init) ?? info.mime) : ext
        self.init(name: info.name, kind: kind.uppercased(), size: .init(value: Double(info.size), unit: .bytes))
    }
}
