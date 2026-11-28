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
    /// Signs in again an account with its own servers with a new password, checked with
    /// both servers; refused, it is `SignedOut` and the old one stays. Network.
    func updateImapPassword(accountId: String, password: String) throws -> NimbraCore.Account

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

    // MARK: Mailboxes · labels, blocking, All inboxes

    /// Disk.
    func cachedAllInboxes() throws -> [NimbraCore.ThreadRow]
    /// Network.
    func allInboxes(perAccount: UInt32) throws -> AllInboxesPage
    /// Network.
    func labels(accountId: String) throws -> [NimbraCore.Label]
    /// Network (disk when it exists).
    func createLabel(accountId: String, name: String) throws -> NimbraCore.Label
    /// Network.
    func renameLabel(accountId: String, labelId: String, name: String) throws
    /// Network.
    func deleteLabel(accountId: String, labelId: String) throws
    /// Network.
    func relabel(accountId: String, threadId: String, add: [String], remove: [String]) throws
    /// Network.
    func moveToLabel(accountId: String, threadId: String, labelId: String, from: Mailbox) throws
    /// Network.
    func blockSender(accountId: String, address: String, threadId: String?, from: Mailbox) throws
    /// Network (disk without a thread).
    func unblockSender(accountId: String, address: String, threadId: String?) throws
    /// Disk.
    func blockedSenders(accountId: String) throws -> [String]
    /// Network; queued when offline.
    func moveToInbox(accountId: String, threadId: String, from: Mailbox) throws -> ActionOutcome

    // MARK: Reading

    /// Disk.
    func cachedThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread?
    /// Network.
    func readThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread
    /// An attachment's content. Network.
    func downloadAttachment(accountId: String, messageId: String, attachmentId: String) throws -> Data
    /// One of a message's remote images, when the user asked for them: https on a public
    /// host only, size-capped, with a timeout. Network. (`Engine` answers with the free
    /// function `NimbraCore.fetchRemoteImage`.)
    func fetchRemoteImage(url: String) throws -> Data
    /// When an opened thread counts as read: at once (0), after a moment, or only when the
    /// user says so (nil).
    func markReadAfterMs() -> UInt32?
    /// Disk.
    func preferences() -> Preferences

    // MARK: Actions

    /// Network; queued when offline.
    func apply(accountId: String, threadId: String, action: ThreadAction) throws -> ActionOutcome
    /// Deletes a thread for good, from the server too (Gmail may need `NeedsFullAccess`
    /// first: Google's full mail access). Network.
    func deleteThread(accountId: String, threadId: String) throws
    /// Network (disk when it is already out).
    func snooze(accountId: String, threadId: String, untilMs: Int64, onlyIfNoReply: Bool) throws
    /// Disk.
    func snoozed(accountId: String) throws -> [SnoozedThread]

    // MARK: Compose

    /// The account's signatures, its default marked. Disk.
    func signatures(accountId: String) -> [SignatureInfo]
    /// What a reply, reply-all or forward starts with. Disk, else network.
    func startAnswer(accountId: String, threadId: String, kind: AnswerKind, dateText: String) throws -> DraftStart
    /// Network.
    func saveDraft(accountId: String, draftId: String?, message: OutgoingMessage) throws -> String
    /// Network.
    func deleteDraft(accountId: String, draftId: String) throws
    /// The draft in a Drafts thread. Network.
    func draftForThread(accountId: String, threadId: String) throws -> DraftMessage
    /// Address suggestions, best first. Disk.
    func suggestContacts(accountId: String, query: String, present: [String]) throws -> [NimbraCore.Person]
    /// Learns a little more about who the account writes with, for the suggestions (one
    /// page of Sent or of the mail that came in). Whether there is more to learn. Network.
    func learnContacts(accountId: String) throws -> Bool
    /// How long to wait before each `learnContacts` step, so it never competes with the
    /// mail being read. (`Engine` answers with the free function.)
    func contactScanPauseSeconds() -> UInt32

    // MARK: Sending

    /// Checks and keeps the message, held for the undo time. Disk and Keychain.
    func queueSend(accountId: String, message: OutgoingMessage, draftId: String?) throws -> OutgoingSend
    /// What an earlier run left unsent. Network.
    func unsent(accountId: String) throws -> UnsentReport
    /// A send `deliver` left waiting: `catchUp` sends it.
    func waitForConnection(send: OutgoingSend)
    /// Network.
    func catchUp(accountId: String) throws -> CatchUpResult
    /// What waits, and when to look again. Disk.
    func pendingWork(accountId: String) throws -> PendingWork
    /// Network.
    func scheduleSend(accountId: String, message: OutgoingMessage, draftId: String?, atMs: Int64) throws -> ScheduledSend
    /// Disk.
    func scheduledSends(accountId: String) throws -> [ScheduledSend]
    /// Disk.
    func cancelScheduled(accountId: String, draftId: String) throws
    /// Network.
    func sendDue(accountId: String) throws -> [String]

    // MARK: Notifications

    /// Cancels a snooze (Undo): the thread back in the inbox. Network.
    func unsnooze(accountId: String, threadId: String) throws
    /// Brings back the snoozes due by now; the ones that came back. Network.
    func wakeDue(accountId: String) throws -> [SnoozedThread]
    /// What changed since `cursor`, and what to notify about. Network.
    func checkForChanges(accountId: String, cursor: String?) throws -> SyncResult
    /// The app icon's number (0 when the badge is off). Disk.
    func badgeCount() throws -> UInt32

    // MARK: Settings

    /// Disk.
    func setPreferences(preferences: Preferences) throws
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

    // MARK: Reading

    /// The engine's free function, as a method fakes can answer.
    func fetchRemoteImage(url: String) throws -> Data {
        try NimbraCore.fetchRemoteImage(url: url)
    }

    // MARK: Compose

    /// The engine's free function, as a method fakes can answer.
    func contactScanPauseSeconds() -> UInt32 {
        NimbraCore.contactScanPauseSeconds()
    }
}
