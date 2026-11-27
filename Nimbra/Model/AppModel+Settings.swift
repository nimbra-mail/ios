import Foundation
import NimbraCore

/// Settings: the engine's preferences, each account's signatures, removing an account from
/// Settings, and which accounts notify.
extension AppModel {
    // MARK: Preferences

    /// Reads the preferences the engine keeps. Disk.
    func loadPreferences() async {
        if let read = await engine(work: { $0.preferences() }) { preferences = read }
    }

    /// Changes one preference: shown at once, kept by the engine, and put back when the
    /// engine refuses it (the alert says why).
    func setPreference<Value: Equatable>(_ keyPath: WritableKeyPath<Preferences, Value>, _ value: Value) async {
        let before = preferences[keyPath: keyPath]
        guard before != value else { return }
        preferences[keyPath: keyPath] = value
        let changed = preferences
        if await engine(report: true, work: { try $0.setPreferences(preferences: changed) }) == nil {
            preferences[keyPath: keyPath] = before
        }
    }

    // MARK: Signatures

    /// Reads an account's signatures. Disk.
    func loadSignatures(_ account: Account.ID) async {
        if let read = await engine(for: account, work: { $0.signatures(accountId: account) }) {
            signatures[account] = read
        }
    }

    /// Keeps a signature: a new one (`id` nil) is added first. Whether it was kept; a
    /// failure is in `alert`. `isDefault` makes it the account's default, or takes that
    /// away (then new messages start without one).
    @discardableResult
    func saveSignature(_ id: String?, account: Account.ID, name: String, html: String, isDefault: Bool) async -> Bool {
        let saved = await engine(for: account, report: true) { engine -> String in
            let id = try id ?? engine.addSignature(accountId: account)
            try engine.updateSignature(signatureId: id, name: name, html: html)
            let wasDefault = engine.signatures(accountId: account).first { $0.id == id }?.isDefault ?? false
            if isDefault != wasDefault {
                try engine.setDefaultSignature(accountId: account, signatureId: isDefault ? id : nil)
            }
            return id
        }
        await loadSignatures(account)
        return saved != nil
    }

    /// Deletes a signature. Mail already sent and drafts keep it.
    @discardableResult
    func deleteSignature(_ signature: SignatureInfo) async -> Bool {
        let deleted: Void? = await engine(for: signature.accountId, report: true) { try $0.deleteSignature(signatureId: signature.id) }
        await loadSignatures(signature.accountId)
        return deleted != nil
    }

    // MARK: Accounts

    /// Removes an account from Settings: as `removeAccount`, and Settings closes after the
    /// last one (Welcome is next). Whether it was removed.
    @discardableResult
    func removeAccountInSettings(_ id: Account.ID) async -> Bool {
        await removeAccount(id)
        let removed = !accounts.contains { $0.id == id }
        if removed {
            signatures[id] = nil
            if accounts.isEmpty { showsSettings = false }
        }
        return removed
    }

    /// Add account from Settings: Settings closes, then the add-account sheet opens
    /// (`settingsClosed`), as one sheet cannot open over the other from the root.
    func addAccountFromSettings() {
        addsAccountAfterSettings = true
        showsSettings = false
    }

    /// The Settings sheet went away.
    func settingsClosed() {
        guard addsAccountAfterSettings else { return }
        addsAccountAfterSettings = false
        addingAccount = .providers
    }
}
