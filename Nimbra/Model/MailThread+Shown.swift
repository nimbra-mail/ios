import Foundation

/// The words shown where mail has none, as the Mac shows them (its `shown_subject`,
/// `shown_sender` and the reader's `latest_from`): "Untitled" for no subject; "Draft" for
/// a draft to no one yet and "Unknown sender" elsewhere; "Me" for one of the user's own
/// addresses sent without a name.
nonisolated extension MailThread {
    /// The subject to show: "Untitled" when it has none (a draft just begun, say), also in
    /// place of the "(no subject)" a listing may have put there.
    var shownSubject: String { Self.shownSubject(subject) }

    static func shownSubject(_ subject: String) -> String {
        switch subject.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "", "(no subject)": String(localized: "Untitled")
        default: subject
        }
    }

    /// Whether the row names someone: not when it has no name or address (a draft with no
    /// recipients yet), whatever a listing put there instead.
    var namesSomeone: Bool {
        sender.map(Self.names) ?? false
    }

    /// The name a row shows: the sender's name, else their address; in Drafts "Draft" for
    /// one to no one yet, elsewhere "Unknown sender".
    func shownSender(drafts: Bool) -> String {
        if let sender, namesSomeone {
            let name = sender.name.trimmingCharacters(in: .whitespaces)
            return Self.isName(name) ? name : sender.email.trimmingCharacters(in: .whitespaces)
        }
        return drafts ? String(localized: "Draft") : String(localized: "Unknown sender")
    }

    /// Who a message is from, as the reader names them: their name; "Me" for one of
    /// `own` (the accounts' addresses) without a name; else the address; else as a row
    /// names no one.
    static func shownFrom(_ person: Person, own: [String], drafts: Bool) -> String {
        let name = person.name.trimmingCharacters(in: .whitespaces)
        if isName(name) { return name }
        let address = person.email.trimmingCharacters(in: .whitespaces)
        if !address.isEmpty, own.contains(where: { $0.caseInsensitiveCompare(address) == .orderedSame }) {
            return String(localized: "Me")
        }
        if !address.isEmpty { return address }
        return drafts ? String(localized: "Draft") : String(localized: "Unknown sender")
    }

    private static func names(_ person: Person) -> Bool {
        isName(person.name.trimmingCharacters(in: .whitespaces)) || !person.email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// A name, not the stand-in a listing may have put for none.
    private static func isName(_ name: String) -> Bool {
        !name.isEmpty && name != "Unknown sender"
    }
}

nonisolated extension Message {
    /// Nothing in it to show (an empty draft): the reader says so rather than a blank.
    var hasNoContent: Bool {
        guard body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, blocks.isEmpty else { return false }
        guard let html else { return true }
        if html.range(of: "<img", options: .caseInsensitive) != nil { return false }
        let text = html
            .replacing(/<(?:style|script|head)\b[^>]*>[\s\S]*?<\/(?:style|script|head)\s*>/.ignoresCase(), with: "")
            .replacing(/<[^>]*>/, with: "")
            .replacing(/&nbsp;|&#160;|&zwnj;|&#8204;/.ignoresCase(), with: "")
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension AppModel {
    /// Who a message in `thread` is from, as the reader names them (`shownFrom`).
    func shownFrom(_ message: Message, in thread: MailThread.ID) -> String {
        MailThread.shownFrom(message.from, own: accounts.map(\.email), drafts: isInDrafts(thread))
    }

    /// Whether Drafts lists the thread.
    func isInDrafts(_ id: MailThread.ID) -> Bool {
        listings[ListingKey(account: id.account, mailbox: .drafts)]?.threads.contains { $0.id == id } ?? false
    }
}
