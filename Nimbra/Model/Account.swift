import Foundation
import NimbraCore

/// A signed-in mailbox on this device: the engine's account.
nonisolated struct Account: Identifiable, Hashable, Sendable {
    /// What kind of servers it signs in to.
    nonisolated enum Kind: Hashable, Sendable {
        /// Gmail or Google Workspace: Google's sign-in, and Gmail's categories.
        case gmail
        /// Outlook.com or Microsoft 365: Microsoft's sign-in.
        case microsoft
        /// Its own IMAP and SMTP servers, with a password.
        case imap
    }

    /// The engine's id for it.
    let id: String
    let email: String
    let kind: Kind
    /// New messages are from it unless another is picked.
    var isDefault: Bool

    init(id: String, email: String, kind: Kind, isDefault: Bool = false) {
        self.id = id
        self.email = email
        self.kind = kind
        self.isDefault = isDefault
    }

    init(_ account: NimbraCore.Account) {
        let kind: Kind = switch account.kind {
        case .gmail: .gmail
        case .microsoft: .microsoft
        case .imap: .imap
        }
        self.init(id: account.id, email: account.email, kind: kind, isDefault: account.isDefault)
    }

    /// What the account is called in a list: its address's domain ("riangle.com").
    var name: String {
        email.split(separator: "@").last.map(String.init) ?? email
    }

    /// Who it belongs to, for the avatar: the address before the @, with its own tone.
    var person: Person {
        let local = email.split(separator: "@").first.map(String.init) ?? email
        let words = local.split(whereSeparator: { ".-_".contains($0) }).map(\.capitalized)
        return Person(name: words.joined(separator: " "), email: email, tone: .for(email))
    }
}
