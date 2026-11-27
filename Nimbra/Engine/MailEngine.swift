import Foundation
import NimbraCore

/// The engine calls the app makes, as `NimbraCore.Engine` declares them. Every one blocks
/// (disk, Keychain or network, as each `Engine` method's doc says): call them only through
/// `EngineHost.call`, never on the main actor.
///
/// The app depends on this protocol rather than on `Engine`, so previews, the demo launch
/// and tests run on `SampleEngine` or a fake, and the compiler says which of them lacks a
/// call that a feature starts to use. To use another engine call: add its exact signature
/// here (copy it from `NimbraCore.swift`), then give `SampleEngine` and the test fake an
/// answer for it. `Engine` conforms on its own.
nonisolated protocol MailEngine: AnyObject, Sendable {
    // MARK: Setup

    /// Writes what is waiting, for a few seconds at most. Disk.
    func flush() -> Bool
    /// Seconds between two checks for mail, from Preferences.
    func checkIntervalSeconds() -> UInt32
    /// A watch on the account's server for live updates. Disk and Keychain (it connects).
    func changeWatch(accountId: String) throws -> any ChangeWatchProtocol

    // MARK: Accounts

    func accounts() -> [NimbraCore.Account]
    func setDefaultAccount(accountId: String) throws
    /// Disk and Keychain.
    func removeAccount(accountId: String) throws
    func beginGoogleSignIn(redirectUri: String, accountId: String?, fullAccess: Bool) throws -> SignInRequest
    /// Network.
    func finishGoogleSignIn(requestId: String, callbackUrl: String) throws -> NimbraCore.Account
    func beginMicrosoftSignIn(redirectUri: String, accountId: String?, hint: String?) throws -> SignInRequest
    /// Network.
    func finishMicrosoftSignIn(requestId: String, callbackUrl: String) throws -> NimbraCore.Account
    func cancelSignIn(requestId: String)
    /// Network.
    func discoverServers(email: String) throws -> Discovery
    /// Network.
    func addImapAccount(email: String, servers: MailServers, password: String) throws -> NimbraCore.Account

    // MARK: Mailboxes

    /// Disk.
    func mailboxes(accountId: String) throws -> [MailboxEntry]
    /// Disk.
    func cachedThreads(accountId: String, mailbox: Mailbox) throws -> [NimbraCore.ThreadRow]
    /// Network.
    func refreshMailbox(accountId: String, mailbox: Mailbox) throws -> ThreadPage
    /// Network.
    func loadMore(accountId: String, mailbox: Mailbox, page: String) throws -> ThreadPage
    /// Disk.
    func cachedCounts(accountId: String) throws -> [LabelCount]
    /// Network.
    func counts(accountId: String, labelIds: [String]) throws -> [LabelCount]
    /// Network.
    func search(accountId: String, query: String, page: String?, limit: UInt32) throws -> ThreadPage

    // MARK: Reading

    /// Disk.
    func cachedThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread?
    /// Network.
    func readThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread

    // MARK: Actions

    /// Network; queued when offline.
    func apply(accountId: String, threadId: String, action: ThreadAction) throws -> ActionOutcome
    /// Network (disk when it is already out).
    func snooze(accountId: String, threadId: String, untilMs: Int64, onlyIfNoReply: Bool) throws
    /// Disk.
    func snoozed(accountId: String) throws -> [SnoozedThread]

    // MARK: Settings

    /// Disk.
    func preferences() -> Preferences
    /// Disk.
    func setPreferences(preferences: Preferences) throws
    /// The account's signatures, the default marked. Disk.
    func signatures(accountId: String) -> [SignatureInfo]
    /// A new, empty signature for the account. Its id. Disk.
    func addSignature(accountId: String) throws -> String
    /// Its HTML is cleaned before it is kept. Disk.
    func updateSignature(signatureId: String, name: String, html: String) throws
    /// Disk.
    func deleteSignature(signatureId: String) throws
    /// `nil`: no signature by default. Disk.
    func setDefaultSignature(accountId: String, signatureId: String?) throws
}

nonisolated extension Engine: MailEngine {
    /// `watch` under a name that returns the protocol, so fakes can answer it.
    func changeWatch(accountId: String) throws -> any ChangeWatchProtocol {
        try watch(accountId: accountId)
    }
}
