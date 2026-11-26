import Foundation

/// Where adding an account starts: the providers (09 · Add account), or another address
/// straight away (10 · IMAP setup, from Welcome).
nonisolated enum AddAccountStart: Identifiable, Hashable, Sendable {
    case providers, otherAddress

    var id: Self { self }
}

/// What the root view presents for the model: the add-account sheet and alerts.
extension AppModel {
    /// The alert, while it is up. Dismissing it clears it.
    var showsAlert: Bool {
        get { alert != nil }
        set { if !newValue { alert = nil } }
    }

    /// The alert, shown by the root view when no sheet covers it (the sheet shows its own).
    var showsRootAlert: Bool {
        get { alert != nil && addingAccount == nil }
        set { if !newValue { alert = nil } }
    }
}

extension MailError {
    /// The alert's title.
    var title: String {
        switch self {
        case .signedOut: String(localized: "Signed out")
        case .notConfigured: String(localized: "Sign-in isn’t set up")
        case .offline: String(localized: "You’re offline")
        default: String(localized: "That didn’t work")
        }
    }
}
