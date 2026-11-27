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
        // MARK: Mailboxes
        /// Each account's labels (the Mailboxes' labels section), by id and name.
        var labels: [String: [NimbraCore.Label]] = [:]
        var blocked: [String: [String]] = [:]
        var allInboxes: [NimbraCore.ThreadRow] = []
        var snoozed: [String: [SnoozedThread]] = [:]
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
        let labels = state.withLock { $0.labels[accountId, default: Self.travel] }
        return split + [MailboxEntry(mailbox: .starred, section: .mailboxes, name: nil)]
            + labels.map { MailboxEntry(mailbox: .label(id: $0.id), section: .labels, name: $0.name) }
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
    }

    func snoozed(accountId: String) throws -> [SnoozedThread] {
        state.withLock { $0.snoozed[accountId] ?? [] }
    }

    // MARK: Mailboxes · labels, blocking, All inboxes

    /// Every account's labels until a test sets its own.
    static let travel = [NimbraCore.Label(id: "L1", name: "Travel")]

    func cachedAllInboxes() throws -> [NimbraCore.ThreadRow] {
        state.withLock { $0.allInboxes }
    }

    func allInboxes(perAccount: UInt32) throws -> AllInboxesPage {
        try record("allInboxes \(perAccount)", "allInboxes")
        return state.withLock { state in
            let unread = Dictionary(grouping: state.allInboxes.filter(\.unread), by: { $0.accountId ?? "" })
            return AllInboxesPage(
                threads: state.allInboxes,
                unread: unread.map { LabelCount(labelId: $0.key, unread: UInt32($0.value.count), total: 0) },
                failedAccounts: 0
            )
        }
    }

    func labels(accountId: String) throws -> [NimbraCore.Label] {
        try record("labels \(accountId)", "labels")
        return state.withLock { $0.labels[accountId, default: Self.travel] }
    }

    func createLabel(accountId: String, name: String) throws -> NimbraCore.Label {
        try record("createLabel \(name)", "createLabel")
        let label = NimbraCore.Label(id: "new-\(name)", name: name)
        state.withLock { $0.labels[accountId, default: Self.travel].append(label) }
        return label
    }

    func renameLabel(accountId: String, labelId: String, name: String) throws {
        try record("renameLabel \(labelId) \(name)", "renameLabel")
        state.withLock { state in
            state.labels[accountId] = state.labels[accountId, default: Self.travel].map { $0.id == labelId ? NimbraCore.Label(id: labelId, name: name) : $0 }
        }
    }

    func deleteLabel(accountId: String, labelId: String) throws {
        try record("deleteLabel \(labelId)", "deleteLabel")
        state.withLock { $0.labels[accountId, default: Self.travel].removeAll { $0.id == labelId } }
    }

    func relabel(accountId: String, threadId: String, add: [String], remove: [String]) throws {
        try record("relabel \(threadId) +\(add) -\(remove)", "relabel")
    }

    func moveToLabel(accountId: String, threadId: String, labelId: String, from: Mailbox) throws {
        try record("moveToLabel \(threadId) \(labelId) \(from)", "moveToLabel")
    }

    func blockSender(accountId: String, address: String, threadId: String?, from: Mailbox) throws {
        try record("block \(address) \(threadId ?? "-") \(from)", "blockSender")
        state.withLock { $0.blocked[accountId, default: []].append(address) }
    }

    func unblockSender(accountId: String, address: String, threadId: String?) throws {
        try record("unblock \(address) \(threadId ?? "-")", "unblockSender")
        state.withLock { $0.blocked[accountId]?.removeAll { $0 == address } }
    }

    func moveToInbox(accountId: String, threadId: String, from: Mailbox) throws -> ActionOutcome {
        try record("moveToInbox \(threadId) \(from)", "moveToInbox")
        return .done
    }

    func blockedSenders(accountId: String) throws -> [String] {
        state.withLock { $0.blocked[accountId] ?? [] }
    }
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
