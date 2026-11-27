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
        // MARK: Compose
        var drafts: [String: OutgoingMessage] = [:]
        var scheduled: [String: [ScheduledSend]] = [:]
        var waiting: [String: [OutgoingSend]] = [:]
    }

    private let state: Mutex<State>
    /// The demo's offline state (`-Offline YES`): sends wait for the connection.
    private let offline: Bool

    init(accounts: [Account] = SampleData.accounts, items: [SampleData.Item] = SampleData.mail(), offline: Bool = false) {
        state = Mutex(State(accounts: accounts, items: items))
        self.offline = offline
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
        if offline { throw NimbraError.Offline }
        return ThreadPage(threads: try cachedThreads(accountId: accountId, mailbox: mailbox), nextPage: nil)
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

    // MARK: Compose

    func preferences() -> Preferences {
        Preferences(
            notifications: true, originalView: false, loadImages: false, darkEmails: true, markRead: .open,
            checkEverySeconds: 300, undoSendSeconds: 10, quoteReplies: true, badge: true, notificationSound: true
        )
    }

    func signatures(accountId: String) -> [SignatureInfo] {
        guard accountId == SampleData.work.id else { return [] }
        return [SignatureInfo(
            id: "sample-signature", accountId: accountId, name: "Work",
            html: "<div>Luan Gjokaj</div><div>UX Engineer &amp; Designer</div><div><a href=\"https://nimbra.me\">nimbra.me</a></div>",
            isDefault: true
        )]
    }

    func startAnswer(accountId: String, threadId: String, kind: AnswerKind, dateText: String) throws -> DraftStart {
        let thread = try state.withLock { state in
            guard let item = state.items.first(where: { $0.thread.id == .init(account: accountId, thread: threadId) }) else {
                throw NimbraError.NotFound
            }
            return item.thread
        }
        let latest = thread.latest
        let own = try account(accountId).email
        let to: [String] = switch kind {
        case .reply: [latest?.from.email].compactMap(\.self)
        case .replyAll: ([latest?.from].compactMap(\.self) + (latest?.to ?? [])).map(\.email).filter { $0 != own }
        case .forward: []
        }
        let prefix = kind == .forward ? "Fwd: " : "Re: "
        let subject = thread.subject.hasPrefix(prefix) ? thread.subject : prefix + thread.subject
        let quoted = latest.map { "On \(dateText), \($0.from.name) wrote:\n\n" + $0.body }
        let kept = kind == .forward ? (latest.map(Self.message)?.attachments ?? []) : []
        return DraftStart(
            subject: subject, to: to.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }, quoted: quoted, kept: kept,
            reply: kind == .forward ? nil : latest.map { ReplyRef(threadId: threadId, messageId: $0.id) },
            signature: signatures(accountId: accountId).first(where: \.isDefault)
        )
    }

    func saveDraft(accountId: String, draftId: String?, message: OutgoingMessage) throws -> String {
        let id = draftId ?? "sample-draft-\(UUID().uuidString)"
        state.withLock { $0.drafts[id] = message }
        return id
    }

    func deleteDraft(accountId: String, draftId: String) throws {
        state.withLock { _ = $0.drafts.removeValue(forKey: draftId) }
    }

    func draftForThread(accountId: String, threadId: String) throws -> DraftMessage {
        guard let message = state.withLock({ $0.drafts[threadId] }) else { throw NimbraError.NotFound }
        return DraftMessage(
            id: threadId, to: message.to, cc: message.cc, bcc: message.bcc, subject: message.subject, body: message.body,
            quoted: nil, html: message.html, attachments: message.kept, reply: message.reply
        )
    }

    func suggestContacts(accountId: String, query: String, present: [String]) throws -> [NimbraCore.Person] {
        let people = [SampleData.jonah, SampleData.joana, SampleData.jordan, SampleData.mira, SampleData.ana, SampleData.elena]
        let own = Set(state.withLock { $0.accounts.map(\.email) })
        return people
            .filter { !own.contains($0.email) && !present.contains($0.email) }
            .filter { person in
                person.email.lowercased().hasPrefix(query.lowercased())
                    || person.name.split(separator: " ").contains { $0.lowercased().hasPrefix(query.lowercased()) }
            }
            .map { NimbraCore.Person(name: $0.name, address: $0.email) }
    }

    // MARK: Sending

    func queueSend(accountId: String, message: OutgoingMessage, draftId: String?) throws -> OutgoingSend {
        _ = try account(accountId)
        guard !(message.to + message.cc + message.bcc).trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NimbraError.Invalid(message: "Add someone to send it to.")
        }
        let offline = offline
        let at = Date.now.milliseconds + Int64(preferences().undoSendSeconds) * 1000
        return SampleSend(account: accountId, message: message, deliverAtMs: at) {
            Thread.sleep(forTimeInterval: 0.6)
            return offline ? .waitingForConnection : .sent
        }
    }

    func unsent(accountId: String) throws -> UnsentReport {
        UnsentReport(toSend: [], movedToDrafts: [])
    }

    func waitForConnection(send: OutgoingSend) {
        state.withLock { $0.waiting[send.accountId(), default: []].append(send) }
    }

    func catchUp(accountId: String) throws -> CatchUpResult {
        if offline { throw NimbraError.Offline }
        let sent = state.withLock { $0.waiting.removeValue(forKey: accountId)?.count ?? 0 }
        return CatchUpResult(changes: 0, sent: UInt32(sent), movedToDrafts: [], done: true)
    }

    func pendingWork(accountId: String) throws -> PendingWork {
        state.withLock { state in
            let waiting = state.waiting[accountId]?.count ?? 0
            let next = [state.scheduled[accountId]?.map(\.atMs).min(), waiting > 0 ? Date.now.milliseconds + 15_000 : nil]
                .compactMap(\.self).min()
            return PendingWork(queuedChanges: 0, waitingMessages: UInt32(waiting), nextDeadlineMs: next)
        }
    }

    func scheduleSend(accountId: String, message: OutgoingMessage, draftId: String?, atMs: Int64) throws -> ScheduledSend {
        let id = try saveDraft(accountId: accountId, draftId: draftId, message: message)
        let item = ScheduledSend(draftId: id, atMs: atMs, subject: message.subject)
        state.withLock { $0.scheduled[accountId, default: []].append(item) }
        return item
    }

    func scheduledSends(accountId: String) throws -> [ScheduledSend] {
        state.withLock { ($0.scheduled[accountId] ?? []).sorted { $0.atMs < $1.atMs } }
    }

    func cancelScheduled(accountId: String, draftId: String) throws {
        state.withLock { $0.scheduled[accountId]?.removeAll { $0.draftId == draftId } }
    }

    func sendDue(accountId: String) throws -> [String] {
        let now = Date.now.milliseconds
        return state.withLock { state in
            let due = (state.scheduled[accountId] ?? []).filter { $0.atMs <= now }.map(\.draftId)
            state.scheduled[accountId]?.removeAll { due.contains($0.draftId) }
            return due
        }
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
            blocks: [], text: message.body, html: nil,
            attachments: message.attachments.map {
                AttachmentInfo(messageId: message.id, attachmentId: $0.name, name: $0.name, mime: "application/octet-stream",
                               size: UInt64($0.size.converted(to: .bytes).value))
            },
            unsubscribe: nil
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
