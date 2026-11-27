import Foundation
import NimbraCore
import Observation

/// A message being written: new, an answer, a saved draft or a `mailto:` link. Owned by
/// `AppModel.composer` while the composer is up, and by an `OutboxItem` while it is held
/// for Undo send, so Undo brings back exactly what was written.
@Observable
final class Composer: Identifiable {
    /// How it started, for the title.
    nonisolated enum Kind: Hashable, Sendable {
        case new, reply, replyAll, forward, draft
    }

    /// The signature under what is written, kept apart from it as on the Mac.
    nonisolated struct Signature: Hashable, Sendable {
        /// The account's signature it is, when known (a reopened draft's may not be).
        var id: String?
        /// Already cleaned by the engine: safe to show and send.
        var html: String
    }

    /// A file attached from this iPhone.
    nonisolated struct File: Identifiable, Hashable, Sendable {
        let id = UUID()
        var name: String
        var mime: String
        var bytes: Data
    }

    let id = UUID()
    var kind: Kind
    /// The account it is sent from: picked in From, never the account the inbox shows.
    var from: Account.ID
    var to: [String] = []
    var cc: [String] = []
    var bcc: [String] = []
    /// What is typed in To, Cc and Bcc and is not a chip yet.
    var typingTo = ""
    var typingCc = ""
    var typingBcc = ""
    var showsCcBcc = false
    var subject = ""
    /// What was written, as the editor's HTML (a `<div>` per line, as on the Mac).
    var written = ""
    /// What was written, as text.
    var text = ""
    var signature: Signature?
    /// The signature as text, as the editor shows it (for the text part).
    var signatureText = ""
    /// The earlier message, as text, folded under what is written; added when sent.
    var quoted: String?
    /// Files already on the message (a forward's, a draft's).
    var kept: [AttachmentInfo] = []
    var files: [File] = []
    var reply: ReplyRef?
    /// Its draft in the account's Drafts, once saved.
    var draftID: String?
    /// Something to say under the fields: why it was not sent, a file too large.
    var notice: String?
    var isSending = false
    /// A draft save is out; `resave` asks for another once it is back.
    @ObservationIgnored var isSaving = false
    @ObservationIgnored var resave = false

    /// Edits since it opened, and the last that was saved.
    private(set) var edits = 0
    var savedEdits = 0

    nonisolated enum Field: Hashable, Sendable { case to, cc, bcc }

    init(kind: Kind, from: Account.ID) {
        self.kind = kind
        self.from = from
    }

    /// Something changed: it is saved once typing pauses.
    func changed() {
        edits += 1
    }

    var isDirty: Bool { edits != savedEdits }

    /// Anything typed or attached.
    var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(to + cc + bcc).isEmpty
            || [typingTo, typingCc, typingBcc].contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            || !subject.trimmingCharacters(in: .whitespaces).isEmpty
            || !files.isEmpty || !kept.isEmpty
    }

    func chips(_ field: Field) -> [String] {
        switch field {
        case .to: to
        case .cc: cc
        case .bcc: bcc
        }
    }

    /// Where a field's typing is kept.
    static func typing(_ field: Field) -> ReferenceWritableKeyPath<Composer, String> {
        switch field {
        case .to: \.typingTo
        case .cc: \.typingCc
        case .bcc: \.typingBcc
        }
    }

    /// Makes chips of the finished addresses typed in a field (`all`: the last one too).
    func chipify(_ field: Field, all: Bool) {
        let typed = self[keyPath: Self.typing(field)]
        let found = Recipients.chipify(typed, into: chips(field), all: all)
        if found.chips != chips(field) { setChips(found.chips, field) }
        if found.rest != typed { self[keyPath: Self.typing(field)] = found.rest }
    }

    /// Adds an address picked from the suggestions, in place of what was typed.
    func add(_ address: String, to field: Field) {
        if !chips(field).contains(where: { $0.caseInsensitiveCompare(address) == .orderedSame }) {
            setChips(chips(field) + [address], field)
        }
        self[keyPath: Self.typing(field)] = ""
    }

    func setChips(_ chips: [String], _ field: Field) {
        switch field {
        case .to: to = chips
        case .cc: cc = chips
        case .bcc: bcc = chips
        }
    }

    /// Every address in the fields, for suggestions to leave out.
    var present: [String] { to + cc + bcc }

    /// Total size of what is attached, in bytes.
    var attachmentBytes: Int64 {
        files.reduce(0) { $0 + Int64($1.bytes.count) } + kept.reduce(0) { $0 + Int64($1.size) }
    }

    /// The message as it is saved or sent: the text part (what was written, the
    /// signature after "-- ", the quote) and the HTML part the engine builds.
    var outgoing: OutgoingMessage {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let signatureText = signatureText.trimmingCharacters(in: .whitespacesAndNewlines)
        if signature != nil, !signatureText.isEmpty {
            body += "\n\n-- \n" + signatureText
        }
        if let quoted {
            body += "\n\n" + quoted
        }
        return OutgoingMessage(
            to: Recipients.field(to, typing: typingTo),
            cc: Recipients.field(cc, typing: typingCc),
            bcc: Recipients.field(bcc, typing: typingBcc),
            subject: subject,
            body: body,
            html: messageHtml(written: written, signature: signature?.html, quoted: quoted),
            files: files.map { OutgoingFile(name: $0.name, mime: $0.mime, bytes: $0.bytes) },
            kept: kept,
            reply: reply
        )
    }
}

extension Composer {
    /// A draft's parts back in a composer: its fields, what was written without the quote,
    /// and the signature it was saved with, kept apart.
    convenience init(draft: DraftMessage, from: Account.ID) {
        self.init(kind: .draft, from: from)
        to = Recipients.chips(draft.to)
        cc = Recipients.chips(draft.cc)
        bcc = Recipients.chips(draft.bcc)
        showsCcBcc = !cc.isEmpty || !bcc.isEmpty
        subject = draft.subject
        let parts = splitDraftHtml(html: draft.html ?? textToHtml(text: draft.body))
        written = Self.unwrapped(parts.written)
        signature = parts.signature.map { Signature(id: nil, html: $0) }
        quoted = draft.quoted
        kept = draft.attachments
        reply = draft.reply
        draftID = draft.id
    }

    /// What was written without what `message_html` put around it: its `<div dir="ltr">`
    /// and, before a quote, the line break. `split_draft_html` (core 0.1.0) leaves both, so
    /// each save and reopen would nest another wrapper and add an empty line.
    nonisolated static func unwrapped(_ html: String) -> String {
        var html = html
        if html.hasSuffix("</div><br>") { html.removeLast("<br>".count) }
        let open = "<div dir=\"ltr\">", close = "</div>"
        guard html.hasPrefix(open), html.hasSuffix(close) else { return html }
        let inner = String(html.dropFirst(open.count).dropLast(close.count))
        // Only when that outer div is one element: its own close is the last one.
        var depth = 0
        var rest = Substring(inner)
        while let tag = rest.firstRange(of: /<\/?div\b/) {
            depth += rest[tag].hasPrefix("</") ? -1 : 1
            if depth < 0 { return html }
            rest = rest[tag.upperBound...]
        }
        return depth == 0 ? inner : html
    }

    /// A `mailto:` link's message.
    convenience init(mailto: MailtoDraft, from: Account.ID) {
        self.init(kind: .new, from: from)
        to = mailto.to
        cc = mailto.cc
        bcc = mailto.bcc
        showsCcBcc = !cc.isEmpty || !bcc.isEmpty
        subject = mailto.subject
        written = mailto.body.isEmpty ? "" : textToHtml(text: mailto.body)
        text = mailto.body
    }
}
