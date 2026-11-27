import Foundation
import NimbraCore
import Synchronization

/// An engine over `SampleData`, kept in memory: what the previews, the tests and the demo
/// launch (`-SignedIn YES`, for screenshots) run on. It answers like the real engine, so
/// the app takes the same path as with real mail, without a network, a Keychain or a file.
/// Signing in is not possible on it.
nonisolated final class SampleEngine: MailEngine {
    private struct State {
        var accounts: [Account]
        var items: [SampleData.Item]
        var snoozed: [SnoozedThread] = []
    }

    private let state: Mutex<State>

    init(accounts: [Account] = SampleData.accounts, items: [SampleData.Item] = SampleData.mail()) {
        state = Mutex(State(accounts: accounts, items: items))
    }

    // MARK: Setup

    func flush() -> Bool { true }
    func checkIntervalSeconds() -> UInt32 { 300 }
    func changeWatch(accountId: String) throws -> any ChangeWatchProtocol { SampleWatch() }

    // MARK: Accounts

    func accounts() -> [NimbraCore.Account] {
        state.withLock { $0.accounts.map(Self.core) }
    }

    func setDefaultAccount(accountId: String) throws {
        try state.withLock { state in
            guard state.accounts.contains(where: { $0.id == accountId }) else { throw Self.unknownAccount }
            for index in state.accounts.indices {
                state.accounts[index].isDefault = state.accounts[index].id == accountId
            }
        }
    }

    func removeAccount(accountId: String) throws {
        state.withLock { state in
            state.accounts.removeAll { $0.id == accountId }
            state.items.removeAll { $0.thread.id.account == accountId }
        }
    }

    func beginGoogleSignIn(redirectUri: String, accountId: String?, fullAccess: Bool) throws -> SignInRequest {
        throw Self.noSignIn
    }

    func finishGoogleSignIn(requestId: String, callbackUrl: String) throws -> NimbraCore.Account {
        throw Self.noSignIn
    }

    func beginMicrosoftSignIn(redirectUri: String, accountId: String?, hint: String?) throws -> SignInRequest {
        throw Self.noSignIn
    }

    func finishMicrosoftSignIn(requestId: String, callbackUrl: String) throws -> NimbraCore.Account {
        throw Self.noSignIn
    }

    func cancelSignIn(requestId: String) {}

    func discoverServers(email: String) throws -> Discovery {
        if let known = knownServers(email: email) { return known }
        return .unknown
    }

    func addImapAccount(email: String, servers: MailServers, password: String) throws -> NimbraCore.Account {
        throw Self.noSignIn
    }

    // MARK: Mailboxes

    func mailboxes(accountId: String) throws -> [MailboxEntry] {
        let account = try account(accountId)
        let split: [MailboxEntry] = account.kind == .gmail
            ? [MailboxEntry(mailbox: .inbox, section: .split, name: nil)]
                + SplitCategory.allCases.map { MailboxEntry(mailbox: $0.mailbox, section: .split, name: nil) }
            : []
        let names = state.withLock { state in
            Set(state.items.filter { $0.thread.id.account == accountId }.flatMap(\.thread.labels)).sorted()
        }
        return split
            + [MailboxEntry(mailbox: account.kind == .gmail ? .starred : .inbox, section: .mailboxes, name: nil)]
            + names.map { MailboxEntry(mailbox: .label(id: Self.labelID($0)), section: .labels, name: $0) }
    }

    func cachedThreads(accountId: String, mailbox: Mailbox) throws -> [NimbraCore.ThreadRow] {
        _ = try account(accountId)
        return state.withLock { state in
            let snoozed = Set(state.snoozed.map(\.threadId))
            return state.items
                .filter { $0.thread.id.account == accountId && !snoozed.contains($0.thread.id.thread) }
                .filter { item in
                    switch mailbox {
                    case .inbox: true
                    case .split(let category): item.category.map(\.mailbox) == .split(category: category)
                    case .starred: item.thread.isStarred
                    case .label(let id): item.thread.labels.map(Self.labelID).contains(id)
                    default: false
                    }
                }
                .sorted { $0.thread.date > $1.thread.date }
                .map(Self.row)
        }
    }

    func refreshMailbox(accountId: String, mailbox: Mailbox) throws -> ThreadPage {
        ThreadPage(threads: try cachedThreads(accountId: accountId, mailbox: mailbox), nextPage: nil)
    }

    func loadMore(accountId: String, mailbox: Mailbox, page: String) throws -> ThreadPage {
        ThreadPage(threads: [], nextPage: nil)
    }

    func cachedCounts(accountId: String) throws -> [LabelCount] {
        _ = try account(accountId)
        return state.withLock { state in
            let unread = state.items.filter { $0.thread.id.account == accountId && $0.thread.isUnread }
            let inbox = LabelCount(labelId: "INBOX", unread: UInt32(unread.count), total: UInt32(unread.count))
            return [inbox] + SplitCategory.allCases.map { category in
                let count = UInt32(unread.count { $0.category == category })
                return LabelCount(labelId: category.labelID, unread: count, total: count)
            }
        }
    }

    func counts(accountId: String, labelIds: [String]) throws -> [LabelCount] {
        try cachedCounts(accountId: accountId).filter { labelIds.contains($0.labelId) }
    }

    func search(accountId: String, query: String, page: String?, limit: UInt32) throws -> ThreadPage {
        let words = query.split(whereSeparator: \.isWhitespace)
        let rows = state.withLock { state in
            state.items.filter { item in
                guard item.thread.id.account == accountId, !words.isEmpty else { return false }
                let thread = item.thread
                let text = ([thread.subject] + thread.messages.flatMap { [$0.from.name, $0.from.email, $0.body] })
                    .joined(separator: " ")
                return words.allSatisfy { text.localizedStandardContains($0) }
            }
            .sorted { $0.thread.date > $1.thread.date }
            .map(Self.row)
        }
        return ThreadPage(threads: rows, nextPage: nil)
    }

    // MARK: Reading

    func cachedThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread? {
        try readThread(accountId: accountId, threadId: threadId)
    }

    func readThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread {
        try state.withLock { state in
            guard let item = state.items.first(where: { $0.thread.id == .init(account: accountId, thread: threadId) }) else {
                throw NimbraError.NotFound
            }
            return NimbraCore.MailThread(id: threadId, messages: item.thread.messages.map(Self.message))
        }
    }

    // MARK: Reading (files, images, Preferences)

    /// A small PDF that says what it stands for, for any attachment.
    func downloadAttachment(accountId: String, messageId: String, attachmentId: String) throws -> Data {
        SampleFiles.pdf(title: attachmentId)
    }

    /// A picture drawn here: the sample mail never reaches the web.
    func fetchRemoteImage(url: String) throws -> Data {
        SampleFiles.picture()
    }

    func markReadAfterMs() -> UInt32? { 0 }

    func preferences() -> Preferences {
        Preferences(
            notifications: true, originalView: true, loadImages: false, darkEmails: true, markRead: .open,
            checkEverySeconds: 300, undoSendSeconds: 10, quoteReplies: true, badge: true, notificationSound: true
        )
    }

    // MARK: Actions

    func apply(accountId: String, threadId: String, action: ThreadAction) throws -> ActionOutcome {
        try state.withLock { state in
            let id = MailThread.ID(account: accountId, thread: threadId)
            guard let index = state.items.firstIndex(where: { $0.thread.id == id }) else { throw NimbraError.NotFound }
            switch action {
            case .markRead: state.items[index].thread.isUnread = false
            case .markUnread: state.items[index].thread.isUnread = true
            case .star: state.items[index].thread.isStarred = true
            case .unstar: state.items[index].thread.isStarred = false
            case .done, .trash, .spam: state.items.remove(at: index)
            case .moveToInbox, .untrash, .notSpam: break
            }
            return .done
        }
    }

    func snooze(accountId: String, threadId: String, untilMs: Int64, onlyIfNoReply: Bool) throws {
        try state.withLock { state in
            let id = MailThread.ID(account: accountId, thread: threadId)
            guard let thread = state.items.first(where: { $0.thread.id == id })?.thread else { throw NimbraError.NotFound }
            state.snoozed.removeAll { $0.threadId == threadId }
            state.snoozed.append(SnoozedThread(
                threadId: threadId, accountId: accountId, untilMs: untilMs, onlyIfNoReply: onlyIfNoReply,
                subject: thread.subject, sender: thread.sender?.name ?? "", snippet: thread.snippet
            ))
            state.snoozed.sort { $0.untilMs < $1.untilMs }
        }
    }

    func snoozed(accountId: String) throws -> [SnoozedThread] {
        state.withLock { $0.snoozed.filter { $0.accountId == accountId } }
    }

    // MARK: Converting

    private func account(_ id: String) throws -> Account {
        guard let account = state.withLock({ $0.accounts.first { $0.id == id } }) else { throw Self.unknownAccount }
        return account
    }

    private static let unknownAccount = NimbraError.Invalid(message: "There is no such account here.")
    private static let noSignIn = NimbraError.Failed(message: "The sample mail has no sign-in.")

    private static func labelID(_ name: String) -> String { "Label_\(name)" }

    private static func core(_ account: Account) -> NimbraCore.Account {
        let kind: AccountKind = switch account.kind {
        case .gmail: .gmail
        case .microsoft: .microsoft
        case .imap: .imap
        }
        return NimbraCore.Account(id: account.id, email: account.email, kind: kind, isDefault: account.isDefault)
    }

    private static func row(_ item: SampleData.Item) -> NimbraCore.ThreadRow {
        let thread = item.thread
        let labels = ["INBOX"] + (item.category.map { [$0.labelID] } ?? []) + thread.labels.map(labelID)
        return NimbraCore.ThreadRow(
            id: thread.id.thread, accountId: nil, sender: thread.sender?.name ?? "", subject: thread.subject,
            snippet: thread.snippet, timestampMs: thread.date.milliseconds, messageCount: UInt32(thread.messageCount),
            unread: thread.isUnread, starred: thread.isStarred, labels: labels,
            participants: thread.participants.map(\.firstName).joined(separator: ", "), loaded: true
        )
    }

    private static func message(_ message: Message) -> MailMessage {
        let person = { (p: Person) in NimbraCore.Person(name: p.name, address: p.email) }
        return MailMessage(
            from: person(message.from), to: message.to.map(person), cc: [], replyTo: nil,
            sender: message.from.name, address: message.from.email, others: message.to.map(\.email),
            messageId: message.id, timestampMs: message.date.milliseconds, snippet: message.preview,
            blocks: message.blocks, text: message.body, html: message.html,
            attachments: message.attachments.map {
                AttachmentInfo(messageId: message.id, attachmentId: $0.name, name: $0.name, mime: $0.mime,
                               size: UInt64($0.size.converted(to: .bytes).value))
            },
            unsubscribe: message.unsubscribe
        )
    }
}

/// The sample mail never changes on its own: a wait lasts its whole interval.
private nonisolated final class SampleWatch: ChangeWatchProtocol {
    private let cancelled = Atomic(false)

    func cancel() { cancelled.store(true, ordering: .relaxed) }

    func wait(seconds: UInt32) -> WatchOutcome {
        let end = ContinuousClock.now + .seconds(seconds)
        while ContinuousClock.now < end {
            if cancelled.load(ordering: .relaxed) { return .cancelled }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return .timedOut
    }
}
