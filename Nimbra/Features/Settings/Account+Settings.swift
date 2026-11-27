import NimbraCore
import SwiftUI

extension Account {
    /// Who signs it in again: Google or Microsoft (an account with its own servers takes
    /// its password again in its setup instead).
    var provider: OAuthProvider? {
        switch kind {
        case .gmail: .google
        case .microsoft: .microsoft
        case .imap: nil
        }
    }
}

extension Account.Kind {
    /// What the account is, after its address ("luan@riangle.com · Gmail").
    var label: LocalizedStringResource {
        switch self {
        case .gmail: "Gmail"
        case .microsoft: "Microsoft"
        case .imap: "IMAP"
        }
    }
}

extension SignatureInfo {
    /// Its name, or "Untitled" for one without.
    var displayName: Text {
        let name = name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? Text("Untitled") : Text(verbatim: name)
    }
}
