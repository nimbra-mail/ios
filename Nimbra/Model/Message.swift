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
    // MARK: Reading
    /// The body as the engine's reader blocks (headings, lists, quotes, links, images).
    /// Empty: `body` is shown as it is.
    var blocks: [TextBlock] = []
    /// The original HTML, for the locked-down web view (`MailWebView`).
    var html: String?
    /// Where to unsubscribe (`https:` or `mailto:`), from List-Unsubscribe.
    var unsubscribe: String?

    init(
        id: String = UUID().uuidString, from: Person, to: [Person], date: Date, body: String,
        attachments: [Attachment] = [], blocks: [TextBlock] = [], html: String? = nil, unsubscribe: String? = nil
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.date = date
        self.body = body
        self.attachments = attachments
        self.blocks = blocks
        self.html = html
        self.unsubscribe = unsubscribe
    }

    /// A message as the engine parsed it: its plain text, and its files.
    init(_ message: MailMessage) {
        self.init(
            id: message.messageId.isEmpty ? UUID().uuidString : message.messageId,
            from: Person(message.from),
            to: (message.to + message.cc).map(Person.init),
            date: Date(milliseconds: message.timestampMs),
            body: message.text,
            attachments: message.attachments.map(Attachment.init),
            blocks: message.blocks,
            html: message.html,
            unsubscribe: message.unsubscribe
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
    // MARK: Reading
    /// Where the engine finds it (`downloadAttachment`): its message and its own id.
    var messageID = ""
    var attachmentID = ""
    var mime = "application/octet-stream"

    init(name: String, kind: String, size: Measurement<UnitInformationStorage>, messageID: String = "", attachmentID: String = "", mime: String = "application/octet-stream") {
        self.name = name
        self.kind = kind
        self.size = size
        self.messageID = messageID
        self.attachmentID = attachmentID
        self.mime = mime
    }

    /// The engine's file: its kind is its extension ("PDF"), else what its type says.
    init(_ info: AttachmentInfo) {
        let ext = (info.name as NSString).pathExtension
        let kind = ext.isEmpty ? (info.mime.split(separator: "/").last.map(String.init) ?? info.mime) : ext
        self.init(
            name: info.name, kind: kind.uppercased(), size: .init(value: Double(info.size), unit: .bytes),
            messageID: info.messageId, attachmentID: info.attachmentId, mime: info.mime
        )
    }
}
