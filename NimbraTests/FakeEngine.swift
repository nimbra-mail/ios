import Foundation
import NimbraCore
import Synchronization
@testable import Nimbra

/// An engine the tests set up: accounts, rows by mailbox, counts, and failures to throw.
/// It records every call that changes something.
nonisolated final class FakeEngine: MailEngine {
    struct State {
        var accounts: [NimbraCore.Account] = []
        var cached: [ListingKey: [NimbraCore.ThreadRow]] = [:]
        /// What `refreshMailbox` brings (then kept as cached).
        var fresh: [ListingKey: ThreadPage] = [:]
        var more: [ListingKey: ThreadPage] = [:]
        var counts: [String: [LabelCount]] = [:]
        var discovery: Discovery = .unknown
        /// A failure for the next call of a method, by its name ("apply", "refreshMailbox").
        var failures: [String: NimbraError] = [:]
        var calls: [String] = []
        var added: NimbraCore.Account?
        // MARK: Compose
        /// Preferences' undo time, which `queueSend` holds for.
        var undoSendSeconds: UInt32 {
            get { preferences.undoSendSeconds }
            set { preferences.undoSendSeconds = newValue }
        }
        var signatures: [String: [SignatureInfo]] = [:]
        var start: DraftStart?
        var draft: DraftMessage?
        var contacts: [NimbraCore.Person] = []
        var savedDrafts: [OutgoingMessage] = []
        // MARK: Sending
        /// What `deliver` says, in turn; `.sent` once they run out.
        var outcomes: [SendOutcome] = []
        var sends: [SampleSend] = []
        var unsent = UnsentReport(toSend: [], movedToDrafts: [])
        var waiting: [String: Int] = [:]
        var catchUp = CatchUpResult(changes: 0, sent: 0, movedToDrafts: [], done: true)
        var scheduled: [ScheduledSend] = []
        /// The time `queueSend` holds from (ms since 1970).
        var now: Int64 = 1_800_000_000_000
        // MARK: Reading
        /// What `readThread` brings, by thread id; else one plain message.
        var threads: [String: NimbraCore.MailThread] = [:]
        /// What `cachedThread` has, by thread id.
        var kept: [String: NimbraCore.MailThread] = [:]
        var markReadAfterMs: UInt32? = 0
        var preferences = Preferences(
            notifications: true, originalView: true, loadImages: false, darkEmails: true, markRead: .open,
            checkEverySeconds: 60, undoSendSeconds: 10, quoteReplies: true, badge: true, notificationSound: false
        )
        /// What `apply` answers when it does not fail.
        var outcome: ActionOutcome = .done
        var files: [String: Data] = [:]
    }

    let state = Mutex(State())

    init(accounts: [NimbraCore.Account] = []) {
        state.withLock { $0.accounts = accounts }
    }

    var calls: [String] { state.withLock { $0.calls } }

    func fail(_ method: String, with error: NimbraError) {
        state.withLock { $0.failures[method] = error }
    }

    private func record(_ call: String, _ method: String) throws {
        try state.withLock { state in
            state.calls.append(call)
            if let error = state.failures.removeValue(forKey: method) { throw error }
        }
    }

    // MARK: Setup

    func flush() -> Bool { true }
    func checkIntervalSeconds() -> UInt32 { 60 }
    func changeWatch(accountId: String) throws -> any ChangeWatchProtocol {
        throw NimbraError.Offline
    }

    // MARK: Accounts

    func accounts() -> [NimbraCore.Account] { state.withLock { $0.accounts } }

    func setDefaultAccount(accountId: String) throws {
        try record("setDefault \(accountId)", "setDefaultAccount")
        state.withLock { state in
            for index in state.accounts.indices { state.accounts[index].isDefault = state.accounts[index].id == accountId }
        }
    }

    func removeAccount(accountId: String) throws {
        try record("remove \(accountId)", "removeAccount")
        state.withLock { $0.accounts.removeAll { $0.id == accountId } }
    }

    func beginGoogleSignIn(redirectUri: String, accountId: String?, fullAccess: Bool) throws -> SignInRequest {
        try record("beginGoogle \(redirectUri)", "beginGoogleSignIn")
        return SignInRequest(id: "request-1", url: "https://accounts.google.com/o/oauth2/v2/auth?state=s")
    }

    func finishGoogleSignIn(requestId: String, callbackUrl: String) throws -> NimbraCore.Account {
        try record("finishGoogle \(requestId) \(callbackUrl)", "finishGoogleSignIn")
        return keepAdded(kind: .gmail)
    }

    func beginMicrosoftSignIn(redirectUri: String, accountId: String?, hint: String?) throws -> SignInRequest {
        try record("beginMicrosoft \(redirectUri)", "beginMicrosoftSignIn")
        return SignInRequest(id: "request-2", url: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")
    }

    func finishMicrosoftSignIn(requestId: String, callbackUrl: String) throws -> NimbraCore.Account {
        try record("finishMicrosoft \(requestId)", "finishMicrosoftSignIn")
        return keepAdded(kind: .microsoft)
    }

    func cancelSignIn(requestId: String) {
        state.withLock { $0.calls.append("cancel \(requestId)") }
    }

    func discoverServers(email: String) throws -> Discovery {
        try record("discover \(email)", "discoverServers")
        return state.withLock { $0.discovery }
    }

    func addImapAccount(email: String, servers: MailServers, password: String) throws -> NimbraCore.Account {
        try record("addImap \(email) \(servers.imap.host):\(servers.imap.port) \(servers.smtp.host):\(servers.smtp.port) \(servers.username)", "addImapAccount")
        return keepAdded(kind: .imap, email: email)
    }

    private func keepAdded(kind: AccountKind, email: String = "new@example.com") -> NimbraCore.Account {
        let account = NimbraCore.Account(id: "added", email: email, kind: kind, isDefault: false)
        state.withLock { $0.accounts.append(account) }
        return account
    }

    // MARK: Mailboxes

    func mailboxes(accountId: String) throws -> [MailboxEntry] {
        let kind = state.withLock { $0.accounts.first { $0.id == accountId }?.kind }
        guard let kind else { throw NimbraError.Invalid(message: "no such account") }
        let split = kind == .gmail
            ? [MailboxEntry(mailbox: .inbox, section: .split, name: nil)]
                + SplitCategory.allCases.map { MailboxEntry(mailbox: $0.mailbox, section: .split, name: nil) }
            : []
        return split + [
            MailboxEntry(mailbox: .starred, section: .mailboxes, name: nil),
            MailboxEntry(mailbox: .label(id: "L1"), section: .labels, name: "Travel"),
        ]
    }

    func cachedThreads(accountId: String, mailbox: Mailbox) throws -> [NimbraCore.ThreadRow] {
        state.withLock { $0.cached[ListingKey(account: accountId, mailbox: mailbox)] ?? [] }
    }

    func refreshMailbox(accountId: String, mailbox: Mailbox) throws -> ThreadPage {
        let key = ListingKey(account: accountId, mailbox: mailbox)
        try record("refresh \(accountId)", "refreshMailbox")
        return state.withLock { state in
            let page = state.fresh[key] ?? ThreadPage(threads: state.cached[key] ?? [], nextPage: nil)
            state.cached[key] = page.threads
            return page
        }
    }

    func loadMore(accountId: String, mailbox: Mailbox, page: String) throws -> ThreadPage {
        try record("loadMore \(page)", "loadMore")
        return state.withLock { $0.more[ListingKey(account: accountId, mailbox: mailbox)] ?? ThreadPage(threads: [], nextPage: nil) }
    }

    func cachedCounts(accountId: String) throws -> [LabelCount] {
        state.withLock { $0.counts[accountId] ?? [] }
    }

    func counts(accountId: String, labelIds: [String]) throws -> [LabelCount] {
        try record("counts \(accountId)", "counts")
        return try cachedCounts(accountId: accountId)
    }

    func search(accountId: String, query: String, page: String?, limit: UInt32) throws -> ThreadPage {
        try record("search \(query)", "search")
        return ThreadPage(threads: [], nextPage: nil)
    }

    // MARK: Reading

    func cachedThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread? {
        state.withLock { $0.kept[threadId] }
    }

    func readThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread {
        try record("read \(threadId)", "readThread")
        if let thread = state.withLock({ $0.threads[threadId] }) { return thread }
        let message = MailMessage(
            from: NimbraCore.Person(name: "Ana Lima", address: "ana@example.com"), to: [], cc: [], replyTo: nil,
            sender: "Ana Lima", address: "ana@example.com", others: [], messageId: "<m1@example.com>",
            timestampMs: 1_800_000_000_000, snippet: "Friday?", blocks: [], text: "Friday at noon?", html: nil,
            attachments: [], unsubscribe: nil
        )
        return NimbraCore.MailThread(id: threadId, messages: [message])
    }

    // MARK: Actions

    func apply(accountId: String, threadId: String, action: ThreadAction) throws -> ActionOutcome {
        try record("apply \(threadId) \(action)", "apply")
        return state.withLock { $0.outcome }
    }

    func snooze(accountId: String, threadId: String, untilMs: Int64, onlyIfNoReply: Bool) throws {
        try record("snooze \(threadId) \(onlyIfNoReply)", "snooze")
    }

    func snoozed(accountId: String) throws -> [SnoozedThread] { [] }

    // MARK: Compose

    func signatures(accountId: String) -> [SignatureInfo] {
        state.withLock { $0.signatures[accountId] ?? [] }
    }

    func startAnswer(accountId: String, threadId: String, kind: AnswerKind, dateText: String) throws -> DraftStart {
        try record("startAnswer \(threadId) \(kind)", "startAnswer")
        guard let start = state.withLock({ $0.start }) else { throw NimbraError.NotFound }
        return start
    }

    func saveDraft(accountId: String, draftId: String?, message: OutgoingMessage) throws -> String {
        try record("saveDraft \(accountId) \(draftId ?? "new")", "saveDraft")
        return state.withLock { state in
            state.savedDrafts.append(message)
            return draftId ?? "d\(state.savedDrafts.count)"
        }
    }

    func deleteDraft(accountId: String, draftId: String) throws {
        try record("deleteDraft \(accountId) \(draftId)", "deleteDraft")
    }

    func draftForThread(accountId: String, threadId: String) throws -> DraftMessage {
        try record("draft \(threadId)", "draftForThread")
        guard let draft = state.withLock({ $0.draft }) else { throw NimbraError.NotFound }
        return draft
    }

    func suggestContacts(accountId: String, query: String, present: [String]) throws -> [NimbraCore.Person] {
        try record("suggest \(query)", "suggestContacts")
        return state.withLock { $0.contacts }.filter { !present.contains($0.address) }
    }

    // MARK: Sending

    func queueSend(accountId: String, message: OutgoingMessage, draftId: String?) throws -> OutgoingSend {
        try record("queueSend \(accountId) \(draftId ?? "none")", "queueSend")
        if message.to.isEmpty && message.cc.isEmpty && message.bcc.isEmpty {
            throw NimbraError.Invalid(message: "Add someone to send it to.")
        }
        return state.withLock { state in
            let at = state.now + Int64(state.undoSendSeconds) * 1000
            let send = SampleSend(account: accountId, message: message, deliverAtMs: at) { [weak self] in
                self?.state.withLock { $0.outcomes.isEmpty ? .sent : $0.outcomes.removeFirst() } ?? .sent
            }
            state.sends.append(send)
            return send
        }
    }

    func unsent(accountId: String) throws -> UnsentReport {
        try record("unsent \(accountId)", "unsent")
        return state.withLock { state in
            let report = state.unsent
            state.unsent = UnsentReport(toSend: [], movedToDrafts: [])
            return report
        }
    }

    func waitForConnection(send: OutgoingSend) {
        state.withLock { state in
            state.calls.append("wait \(send.subject())")
            state.waiting[send.accountId(), default: 0] += 1
        }
    }

    func catchUp(accountId: String) throws -> CatchUpResult {
        try record("catchUp \(accountId)", "catchUp")
        return state.withLock { state in
            state.waiting[accountId] = 0
            return state.catchUp
        }
    }

    func pendingWork(accountId: String) throws -> PendingWork {
        state.withLock { state in
            let waiting = state.waiting[accountId] ?? 0
            return PendingWork(
                queuedChanges: 0, waitingMessages: UInt32(waiting),
                nextDeadlineMs: waiting > 0 ? state.now + 15_000 : state.scheduled.map(\.atMs).min()
            )
        }
    }

    func scheduleSend(accountId: String, message: OutgoingMessage, draftId: String?, atMs: Int64) throws -> ScheduledSend {
        try record("schedule \(atMs)", "scheduleSend")
        let item = ScheduledSend(draftId: draftId ?? "d-later", atMs: atMs, subject: message.subject)
        state.withLock { $0.scheduled.append(item) }
        return item
    }

    func scheduledSends(accountId: String) throws -> [ScheduledSend] {
        state.withLock { $0.scheduled }
    }

    func cancelScheduled(accountId: String, draftId: String) throws {
        try record("cancelScheduled \(draftId)", "cancelScheduled")
        state.withLock { $0.scheduled.removeAll { $0.draftId == draftId } }
    }

    func sendDue(accountId: String) throws -> [String] {
        try record("sendDue \(accountId)", "sendDue")
        return []
    }

    // MARK: Reading (files, images, Preferences)

    func downloadAttachment(accountId: String, messageId: String, attachmentId: String) throws -> Data {
        try record("download \(messageId) \(attachmentId)", "downloadAttachment")
        return state.withLock { $0.files[attachmentId] } ?? Data()
    }

    func fetchRemoteImage(url: String) throws -> Data {
        try record("image \(url)", "fetchRemoteImage")
        return Data([0x89, 0x50, 0x4E, 0x47])
    }

    func markReadAfterMs() -> UInt32? { state.withLock { $0.markReadAfterMs } }

    func preferences() -> Preferences { state.withLock { $0.preferences } }
}

/// Rows and accounts for the tests.
nonisolated enum Fixture {
    static let gmail = NimbraCore.Account(id: "g1", email: "ana@gmail.com", kind: .gmail, isDefault: true)
    static let imap = NimbraCore.Account(id: "i1", email: "ana@example.org", kind: .imap, isDefault: false)

    static func row(_ id: String, unread: Bool = false, at seconds: Int64 = 1_800_000_000, labels: [String] = ["INBOX"]) -> NimbraCore.ThreadRow {
        NimbraCore.ThreadRow(
            id: id, accountId: nil, sender: "Ben", subject: "Subject \(id)", snippet: "Snippet", timestampMs: seconds * 1000,
            messageCount: 1, unread: unread, starred: false, labels: labels, participants: "", loaded: false
        )
    }

    static let oauth = OAuthConfig(
        googleClientID: "1234-abc.apps.googleusercontent.com",
        microsoftClientID: "6731de76-14a6-49ae-97bc-6eba6914391e",
        bundleID: "com.riangle.nimbra"
    )

    @MainActor
    static func app(_ engine: FakeEngine, oauth: OAuthConfig = oauth) -> AppModel {
        AppModel(host: EngineHost(engine: engine, oauth: oauth))
    }
}
