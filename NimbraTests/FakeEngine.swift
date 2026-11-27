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
        // MARK: Notifications
        var preferences = Fixture.preferences
        /// Snoozes by account, soonest first.
        var snoozed: [String: [SnoozedThread]] = [:]
        /// What `wakeDue` brings back, by account (then out of `snoozed`).
        var due: [String: [SnoozedThread]] = [:]
        /// Reminders `wakeDue` drops without bringing them back: somebody replied.
        var answered: Set<String> = []
        /// What `checkForChanges` answers, by account; the cursor it is given is recorded.
        var changes: [String: SyncResult] = [:]
        var badge: UInt32 = 0
        var deadlines: [String: Int64] = [:]
        /// How long `checkForChanges` takes (a slow server).
        var checkDelay: TimeInterval = 0
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

    func cachedThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread? { nil }

    func readThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread {
        try record("read \(threadId)", "readThread")
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
        return .done
    }

    func snooze(accountId: String, threadId: String, untilMs: Int64, onlyIfNoReply: Bool) throws {
        try record("snooze \(threadId) \(onlyIfNoReply)", "snooze")
        state.withLock { state in
            state.snoozed[accountId, default: []].append(SnoozedThread(
                threadId: threadId, accountId: nil, untilMs: untilMs, onlyIfNoReply: onlyIfNoReply,
                subject: "Subject \(threadId)", sender: "Ben", snippet: "Snippet"
            ))
            state.snoozed[accountId]?.sort { $0.untilMs < $1.untilMs }
        }
    }

    func snoozed(accountId: String) throws -> [SnoozedThread] {
        state.withLock { $0.snoozed[accountId] ?? [] }
    }

    // MARK: Notifications

    func preferences() -> Preferences { state.withLock { $0.preferences } }

    func unsnooze(accountId: String, threadId: String) throws {
        try record("unsnooze \(threadId)", "unsnooze")
        state.withLock { $0.snoozed[accountId]?.removeAll { $0.threadId == threadId } }
    }

    func wakeDue(accountId: String) throws -> [SnoozedThread] {
        try record("wakeDue \(accountId)", "wakeDue")
        return state.withLock { state in
            let due = state.due.removeValue(forKey: accountId) ?? []
            let ids = Set(due.map(\.threadId)).union(state.answered)
            state.snoozed[accountId]?.removeAll { ids.contains($0.threadId) }
            return due
        }
    }

    func pendingWork(accountId: String) throws -> PendingWork {
        state.withLock { PendingWork(queuedChanges: 0, waitingMessages: 0, nextDeadlineMs: $0.deadlines[accountId]) }
    }

    func checkForChanges(accountId: String, cursor: String?) throws -> SyncResult {
        try record("check \(accountId) \(cursor ?? "-")", "checkForChanges")
        let delay = state.withLock { $0.checkDelay }
        if delay > 0 { Thread.sleep(forTimeInterval: delay) }
        return state.withLock { state in
            state.changes.removeValue(forKey: accountId)
                ?? SyncResult(cursor: "c-\(accountId)", changedThreads: [], newUnreadInbox: [], named: [], moreNew: 0, notify: state.preferences.notifications, expired: false)
        }
    }

    func badgeCount() throws -> UInt32 { state.withLock { $0.badge } }
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

    static let preferences = Preferences(
        notifications: true, originalView: false, loadImages: false, darkEmails: true, markRead: .open,
        checkEverySeconds: 60, undoSendSeconds: 10, quoteReplies: true, badge: true, notificationSound: true
    )

    static func snoozed(_ id: String, at ms: Int64, reminder: Bool = false) -> SnoozedThread {
        SnoozedThread(threadId: id, accountId: nil, untilMs: ms, onlyIfNoReply: reminder, subject: "Subject \(id)", sender: "Ben", snippet: "Snippet")
    }

    static let oauth = OAuthConfig(
        googleClientID: "1234-abc.apps.googleusercontent.com",
        microsoftClientID: "6731de76-14a6-49ae-97bc-6eba6914391e",
        bundleID: "com.riangle.nimbra"
    )

    @MainActor
    static func app(_ engine: FakeEngine, oauth: OAuthConfig = oauth) -> AppModel {
        let app = AppModel(host: EngineHost(engine: engine, oauth: oauth))
        // MARK: Notifications
        // Never the real notification center, background scheduler or defaults.
        app.notifier = FakeNotifier()
        app.refreshScheduler = FakeRefreshScheduler()
        app.notificationStore = NotificationStore(defaults: UserDefaults(suiteName: "tests.\(UUID().uuidString)")!)
        return app
    }
}
