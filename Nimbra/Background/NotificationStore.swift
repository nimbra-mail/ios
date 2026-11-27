import Foundation

/// What the app keeps about notifications on this device, in its own defaults (no mail in
/// it: account ids and the engine's opaque cursors).
///
/// The per-account switches live here, not in the engine: `Preferences` has one switch for
/// every account (the Mac has no per-account one). An account whose switch is off still
/// has its changes checked, so turning it back on does not bring a backlog of banners.
nonisolated final class NotificationStore: @unchecked Sendable {
    // UserDefaults is thread-safe; it is the only state.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let muted = "Notifications.MutedAccounts"
        static let asked = "Notifications.Asked"
        static let scheduled = "Notifications.ScheduledReturns"
        static func cursor(_ account: Account.ID) -> String { "Notifications.Cursor.\(account)" }
    }

    /// Accounts whose new mail and snoozes do not notify.
    var muted: Set<Account.ID> {
        get { Set(defaults.stringArray(forKey: Key.muted) ?? []) }
        set { defaults.set(newValue.sorted(), forKey: Key.muted) }
    }

    /// 16 · Ask was shown once (turned on or "Not now"): it does not come back by itself.
    var asked: Bool {
        get { defaults.bool(forKey: Key.asked) }
        set { defaults.set(newValue, forKey: Key.asked) }
    }

    /// The snooze returns scheduled as exact notifications (their ids), until `wake_due`
    /// brings the thread back: those are not shown a second time.
    var scheduledReturns: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.scheduled) ?? []) }
        set { defaults.set(newValue.sorted(), forKey: Key.scheduled) }
    }

    /// Where `check_for_changes` reads from next for an account.
    func cursor(_ account: Account.ID) -> String? {
        defaults.string(forKey: Key.cursor(account))
    }

    func setCursor(_ cursor: String?, for account: Account.ID) {
        defaults.set(cursor, forKey: Key.cursor(account))
    }

    /// An account removed from the device: nothing of it stays.
    func forget(_ account: Account.ID) {
        setCursor(nil, for: account)
        muted.remove(account)
    }
}
