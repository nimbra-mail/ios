import Foundation

/// The screens Settings pushes.
nonisolated enum SettingsRoute: Hashable {
    case account(Account.ID)
    /// A signature of the account, or a new one (`nil`).
    case signature(account: Account.ID, id: String?)
    case notifications
    case blockedSenders
    case appearance
    case about

    #if DEBUG
    /// Debug builds open a screen of Settings at launch, for screenshots:
    /// `-Present settings -SettingsScreen account|signature|notifications|appearance|about`.
    static var atLaunch: [SettingsRoute] {
        let account = SampleData.work.id
        return switch UserDefaults.standard.string(forKey: "SettingsScreen") {
        case "account": [.account(account)]
        case "signature": [.account(account), .signature(account: account, id: "sample-signature-work")]
        case "notifications": [.notifications]
        case "appearance": [.appearance]
        case "about": [.about]
        default: []
        }
    }
    #endif
}
