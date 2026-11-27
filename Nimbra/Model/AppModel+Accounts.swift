import Foundation
import NimbraCore

/// Opens a provider's sign-in page and waits for it to come back to `scheme`: the address
/// it came back to, or nil when the person closed it. `SignInSession.authenticator`
/// is the app's (`ASWebAuthenticationSession`); tests pass their own.
typealias WebAuthenticator = @MainActor (_ url: URL, _ scheme: String) async throws -> URL?

/// Accounts: listing them, the one shown, signing in with Google or Microsoft, adding one
/// with its own servers, the default and removing one.
extension AppModel {
    /// The account the inbox shows.
    var account: Account? { accounts.first { $0.id == accountID } }

    /// The engine's accounts, and each one's mailboxes and counts as kept on the device.
    /// Keeps the account shown when it is still there, else shows the default.
    func reloadAccounts() async {
        guard let list = await engine(work: { $0.accounts() }) else { return }
        accounts = list.map(Account.init)
        if accountID == nil || !accounts.contains(where: { $0.id == accountID }) {
            accountID = (accounts.first(where: \.isDefault) ?? accounts.first)?.id
        }
        let ids = Set(accounts.map(\.id))
        listings = listings.filter { ids.contains($0.key.account) }
        signedOut.formIntersection(ids)
        for account in accounts {
            await loadMailboxes(account.id)
            await loadCachedCounts(account.id)
        }
    }

    /// Shows another account's inbox: from the device at once, then up to date.
    func selectAccount(_ id: Account.ID) async {
        guard id != accountID, accounts.contains(where: { $0.id == id }) else { return }
        accountID = id
        await showInbox()
    }

    /// New messages are from this account unless another is picked.
    func makeDefault(_ id: Account.ID) async {
        await engine(for: id, report: true) { try $0.setDefaultAccount(accountId: id) }
        await reloadAccounts()
    }

    /// Removes an account from this device: its sign-in, its stored mail and signatures.
    /// Nothing changes on the server. Back to Welcome after the last one.
    func removeAccount(_ id: Account.ID) async {
        guard await engine(for: id, report: true, work: { try $0.removeAccount(accountId: id) }) != nil else { return }
        mailboxes[id] = nil
        unread[id] = nil
        snoozedThreads[id] = nil
        opened = opened.filter { $0.key.account != id }
        // MARK: Notifications
        notificationStore.forget(id)
        await reloadAccounts()
        if accounts.isEmpty {
            phase = .welcome
        } else {
            await showInbox()
        }
    }

    // MARK: Signing in

    /// Signs in with Google or Microsoft on the provider's own page, and adds the account
    /// (or signs `account` in again). Whether an account was added; a failure is in `alert`,
    /// and closing the page is not one.
    @discardableResult
    func signIn(with provider: OAuthProvider, again account: Account.ID? = nil, authenticate: WebAuthenticator) async -> Bool {
        guard let host else { return false }
        guard let redirect = host.oauth.redirect(for: provider) else {
            alert = .notConfigured(provider)
            return false
        }
        isSigningIn = true
        defer { isSigningIn = false }

        let begun = await engine(for: account, report: true) { engine in
            switch provider {
            case .google: try engine.beginGoogleSignIn(redirectUri: redirect.uri, accountId: account, fullAccess: false)
            case .microsoft: try engine.beginMicrosoftSignIn(redirectUri: redirect.uri, accountId: account, hint: nil)
            }
        }
        guard let request = begun, let url = URL(string: request.url) else { return false }

        let callback: URL?
        do {
            callback = try await authenticate(url, redirect.scheme)
        } catch {
            callback = nil
            alert = .failed(String(localized: "The sign-in page could not open. Try again."))
        }
        guard let callback else {
            await engine { $0.cancelSignIn(requestId: request.id) }
            return false
        }

        let added = await engine(for: account, report: true) { engine in
            switch provider {
            case .google: try engine.finishGoogleSignIn(requestId: request.id, callbackUrl: callback.absoluteString)
            case .microsoft: try engine.finishMicrosoftSignIn(requestId: request.id, callbackUrl: callback.absoluteString)
            }
        }
        guard let added else { return false }
        reached(added.id)
        await accountAdded(Account(added))
        return true
    }

    /// Finds an address's servers: the well-known providers, then autoconfig and MX
    /// records. Network.
    func discoverServers(email: String) async throws(MailError) -> Discovery {
        guard let host else { throw .failed(String(localized: "Nimbra is still opening. Try again.")) }
        let email = email.trimmingCharacters(in: .whitespaces)
        return try await host.call { try $0.discoverServers(email: email) }
    }

    /// Adds an account with its own servers once both take the password. Network.
    func addImapAccount(email: String, servers: MailServers, password: String) async throws(MailError) {
        guard let host else { throw .failed(String(localized: "Nimbra is still opening. Try again.")) }
        let email = email.trimmingCharacters(in: .whitespaces)
        let added = try await host.call { try $0.addImapAccount(email: email, servers: servers, password: password) }
        isOffline = false
        await accountAdded(Account(added))
    }

    /// A new account (or one signed in again): listed, shown, and brought up to date.
    private func accountAdded(_ added: Account) async {
        signedOut.remove(added.id)
        await reloadAccounts()
        accountID = added.id
        phase = .signedIn
        await showInbox()
    }
}

extension AppModel {
    /// The account shown, for a picker: choosing one shows its inbox.
    var shownAccountID: Account.ID? {
        get { accountID }
        set {
            guard let newValue else { return }
            Task { await selectAccount(newValue) }
        }
    }
}
