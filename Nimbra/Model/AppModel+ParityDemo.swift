import Foundation
import NimbraCore

#if DEBUG
/// The demo launch's parity screens, for screenshots: `-InboxFilter unread` (02 · Inbox ·
/// Unread), `-SubjectOwnLine NO` (02 · Inbox · Subject beside), `-EveryAccount YES`
/// (06 · Mailboxes · Every account), `-NewestFirst YES` and `-TextSize large`.
extension AppModel {
    func startParityDemo() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "InboxFilter") == "unread" { inboxFilter = .unread }
        if defaults.object(forKey: "SubjectOwnLine") != nil { preferences.subjectOwnLine = defaults.bool(forKey: "SubjectOwnLine") }
        if defaults.bool(forKey: "NewestFirst") { preferences.newestFirst = true }
        if let size = defaults.string(forKey: "TextSize"), let picked = TextSize.allCases.first(where: { "\($0)" == size }) {
            preferences.textSize = picked
        }
        showsEveryAccount = defaults.bool(forKey: "EveryAccount")
        let shown = preferences
        Task { await engine { try $0.setPreferences(preferences: shown) } }
    }
}
#endif

/// A launch argument of the demo launch, for screenshots; release builds never read one.
nonisolated enum DemoLaunch {
    static func bool(_ key: String) -> Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: key)
        #else
        false
        #endif
    }

    static func string(_ key: String) -> String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: key)
        #else
        nil
        #endif
    }
}
