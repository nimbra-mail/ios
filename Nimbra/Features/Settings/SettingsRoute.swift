import Foundation

/// The screens Settings pushes.
nonisolated enum SettingsRoute: Hashable {
    case account(Account.ID)
    /// A signature of the account, or a new one (`nil`).
    case signature(account: Account.ID, id: String?)
    case notifications
    case blockedSenders
    case appearance
    case privacy
    case about

    #if DEBUG
    /// Debug builds open a screen of Settings at launch, for screenshots:
    /// `-Present settings -SettingsScreen account|signed-out|signature|notifications|appearance|privacy|about`
    /// (`signed-out`: the account with its own servers, its password refused).
    static var atLaunch: [SettingsRoute] {
        let account = SampleData.work.id
        return switch UserDefaults.standard.string(forKey: "SettingsScreen") {
        case "account": [.account(account)]
        case "signed-out": [.account(SampleData.personal.id)]
        case "signature": [.account(account), .signature(account: account, id: "sample-signature-work")]
        case "notifications": [.notifications]
        case "appearance": [.appearance]
        case "privacy": [.privacy]
        case "about": [.about]
        default: []
        }
    }
    #endif
}
