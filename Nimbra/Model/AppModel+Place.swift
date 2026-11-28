import Foundation

/// Where the inbox was left: the account shown and its split inbox category, kept across
/// launches as the Mac opens where it was. Not secret (an account id and a category), so in
/// the app's defaults. A notification's thread opens over it; search is never kept.
nonisolated struct PlaceStore: @unchecked Sendable {
    // UserDefaults is thread-safe; nil keeps nothing (the sample mail, previews).
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
    }

    /// Keeps nothing: for the sample mail, so a demo never moves the real place.
    static let nowhere = PlaceStore(defaults: nil)

    nonisolated struct Place: Equatable, Sendable {
        var account: Account.ID
        var split: SplitCategory?
    }

    private enum Key {
        static let account = "Place.Account"
        static let split = "Place.Split"
    }

    var place: Place? {
        get {
            guard let account = defaults?.string(forKey: Key.account) else { return nil }
            let split = defaults?.string(forKey: Key.split).flatMap { id in SplitCategory.allCases.first { $0.labelID == id } }
            return Place(account: account, split: split)
        }
        nonmutating set {
            defaults?.set(newValue?.account, forKey: Key.account)
            defaults?.set(newValue?.split?.labelID, forKey: Key.split)
        }
    }
}

extension AppModel {
    /// Keeps the account and category shown, once the launch has put back the last ones.
    func keepPlace() {
        guard isPlaceRestored else { return }
        placeStore.place = accountID.map { PlaceStore.Place(account: $0, split: split) }
    }

    /// The account kept from the last run, before the accounts are listed: shown when it is
    /// still on this device (`reloadAccounts` keeps it), else the default.
    func restoreAccount() -> PlaceStore.Place? {
        let place = placeStore.place
        if let place, accountID == nil { accountID = place.account }
        return place
    }

    /// Its category, once the account's mailboxes say whether it has the split inbox.
    func restoreSplit(_ place: PlaceStore.Place?) {
        if let place, place.account == accountID, hasSplitInbox(accountID) { split = place.split }
        isPlaceRestored = true
        keepPlace()
    }
}
