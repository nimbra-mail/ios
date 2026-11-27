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
        // MARK: Mailboxes
        /// Threads outside the inboxes (Drafts, Sent, Done), each in its mailbox.
        var filed: [SampleData.Filed] = []
        /// Each account's labels by name, in order.
        var labels: [String: [String]] = [:]
        var blocked: [String: [String]] = [:]
    }

    private let state: Mutex<State>

    init(accounts: [Account] = SampleData.accounts, items: [SampleData.Item] = SampleData.mail()) {
        let ids = Set(accounts.map(\.id))
        state = Mutex(State(
            accounts: accounts, items: items,
            snoozed: SampleData.reminders().filter { ids.contains($0.accountId ?? "") },
            filed: SampleData.filed().filter { ids.contains($0.thread.id.account) },
            labels: SampleData.labels.filter { ids.contains($0.key) },
            blocked: SampleData.blocked.filter { ids.contains($0.key) }
        ))
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
        let gmail = account.kind == .gmail
        let split: [MailboxEntry] = gmail
            ? [MailboxEntry(mailbox: .inbox, section: .split, name: nil)]
                + SplitCategory.allCases.map { MailboxEntry(mailbox: $0.mailbox, section: .split, name: nil) }
            : []
        // As the engine lists them: an account with its own servers has its inbox here and
        // no Important.
        let boxes: [Mailbox] = (gmail ? [.starred, .important] : [.inbox, .starred])
            + [.snoozed, .reminders, .drafts, .sent, .done, .allMail, .spam, .trash]
        let names = state.withLock { state in
            var names = state.labels[accountId] ?? []
            let used = (state.items.map(\.thread) + state.filed.map(\.thread))
                .filter { $0.id.account == accountId }
                .flatMap(\.labels)
            for name in used where !names.contains(name) { names.append(name) }
            return names
        }
        return split
            + boxes.map { MailboxEntry(mailbox: $0, section: .mailboxes, name: nil) }
            + names.map { MailboxEntry(mailbox: .label(id: Self.labelID($0)), section: .labels, name: $0) }
    }

    func cachedThreads(accountId: String, mailbox: Mailbox) throws -> [NimbraCore.ThreadRow] {
        _ = try account(accountId)
        return state.withLock { state in
            let snoozed = Set(state.snoozed.map(\.threadId))
            let inboxes = state.items
                .filter { $0.thread.id.account == accountId && !snoozed.contains($0.thread.id.thread) }
            let filed = state.filed.filter { $0.thread.id.account == accountId }
            let threads: [MailThread] = switch mailbox {
            case .inbox: inboxes.map(\.thread)
            case .split(let category): inboxes.filter { $0.category.map(\.mailbox) == .split(category: category) }.map(\.thread)
            case .starred: (inboxes.map(\.thread) + filed.map(\.thread)).filter(\.isStarred)
            case .important: inboxes.filter { $0.category == .primary }.map(\.thread)
            case .snoozed, .reminders:
                state.snoozed
                    .filter { $0.accountId == accountId && $0.onlyIfNoReply == (mailbox == .reminders) }
                    .compactMap { snooze in
                        (state.items.map(\.thread) + filed.map(\.thread)).first { $0.id.thread == snooze.threadId }
                    }
            case .allMail: inboxes.map(\.thread) + filed.filter { $0.mailbox != .drafts }.map(\.thread)
            case .label(let id):
                (inboxes.map(\.thread) + filed.map(\.thread)).filter { $0.labels.map(Self.labelID).contains(id) }
            default: filed.filter { $0.mailbox == mailbox }.map(\.thread)
            }
            let categories = Dictionary(state.items.map { ($0.thread.id, $0.category) }, uniquingKeysWith: { a, _ in a })
            return threads
                .sorted { $0.date > $1.date }
                .map { Self.row(SampleData.Item(thread: $0, category: categories[$0.id] ?? nil)) }
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
            let drafts = UInt32(state.filed.count { $0.thread.id.account == accountId && $0.mailbox == .drafts })
            let important = UInt32(unread.count { $0.category == .primary })
            let labels = (state.labels[accountId] ?? []).map { name in
                let count = UInt32(unread.count { $0.thread.labels.contains(name) })
                return LabelCount(labelId: Self.labelID(name), unread: count, total: count)
            }
            return [inbox] + SplitCategory.allCases.map { category in
                let count = UInt32(unread.count { $0.category == category })
                return LabelCount(labelId: category.labelID, unread: count, total: count)
            } + [
                LabelCount(labelId: "DRAFT", unread: 0, total: drafts),
                LabelCount(labelId: "IMPORTANT", unread: important, total: important),
            ] + labels
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

    // MARK: Mailboxes · labels, blocking, All inboxes

    func cachedAllInboxes() throws -> [NimbraCore.ThreadRow] {
        let accounts = state.withLock { $0.accounts }
        return try accounts.flatMap { account in
            try cachedThreads(accountId: account.id, mailbox: .inbox).map { row in
                var row = row
                row.accountId = account.id
                return row
            }
        }
        .sorted { $0.timestampMs > $1.timestampMs }
    }

    func allInboxes(perAccount: UInt32) throws -> AllInboxesPage {
        let rows = try cachedAllInboxes()
        let unread = Dictionary(grouping: rows.filter(\.unread), by: { $0.accountId ?? "" })
        let accounts = state.withLock { $0.accounts }
        return AllInboxesPage(
            threads: rows,
            unread: accounts.map { LabelCount(labelId: $0.id, unread: UInt32(unread[$0.id]?.count ?? 0), total: 0) },
            failedAccounts: 0
        )
    }

    func labels(accountId: String) throws -> [NimbraCore.Label] {
        try mailboxes(accountId: accountId).compactMap { entry in
            guard case .label(let id) = entry.mailbox, let name = entry.name else { return nil }
            return NimbraCore.Label(id: id, name: name)
        }
    }

    func createLabel(accountId: String, name: String) throws -> NimbraCore.Label {
        _ = try account(accountId)
        return state.withLock { state in
            var names = state.labels[accountId] ?? []
            if let known = names.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                return NimbraCore.Label(id: Self.labelID(known), name: known)
            }
            names.append(name)
            state.labels[accountId] = names
            return NimbraCore.Label(id: Self.labelID(name), name: name)
        }
    }

    func renameLabel(accountId: String, labelId: String, name: String) throws {
        try state.withLock { state in
            guard let old = state.labels[accountId]?.first(where: { Self.labelID($0) == labelId }) else { throw NimbraError.NotFound }
            state.labels[accountId] = state.labels[accountId]?.map { $0 == old ? name : $0 }
            Self.relabelAll(in: &state, account: accountId) { $0 == old ? name : $0 }
        }
    }

    func deleteLabel(accountId: String, labelId: String) throws {
        try state.withLock { state in
            guard let old = state.labels[accountId]?.first(where: { Self.labelID($0) == labelId }) else { throw NimbraError.NotFound }
            state.labels[accountId]?.removeAll { $0 == old }
            Self.relabelAll(in: &state, account: accountId) { $0 == old ? nil : $0 }
        }
    }

    func relabel(accountId: String, threadId: String, add: [String], remove: [String]) throws {
        try state.withLock { state in
            let names = state.labels[accountId] ?? []
            let name = { (id: String) in names.first { Self.labelID($0) == id } }
            let change = { (thread: inout MailThread) in
                thread.labels.removeAll { remove.compactMap(name).contains($0) }
                for label in add.compactMap(name) where !thread.labels.contains(label) { thread.labels.append(label) }
            }
            let id = MailThread.ID(account: accountId, thread: threadId)
            if let index = state.items.firstIndex(where: { $0.thread.id == id }) {
                change(&state.items[index].thread)
            } else if let index = state.filed.firstIndex(where: { $0.thread.id == id }) {
                change(&state.filed[index].thread)
            } else {
                throw NimbraError.NotFound
            }
        }
    }

    func moveToLabel(accountId: String, threadId: String, labelId: String, from: Mailbox) throws {
        try relabel(accountId: accountId, threadId: threadId, add: [labelId], remove: [])
        if from == .inbox || from.isInboxLike {
            _ = try apply(accountId: accountId, threadId: threadId, action: .done)
        }
    }

    func blockSender(accountId: String, address: String, threadId: String?, from: Mailbox) throws {
        _ = try account(accountId)
        state.withLock { state in
            if !(state.labels[accountId] ?? []).contains(AppModel.blockedLabel) {
                state.labels[accountId, default: []].append(AppModel.blockedLabel)
            }
            if !(state.blocked[accountId] ?? []).contains(address) { state.blocked[accountId, default: []].append(address) }
        }
        if let threadId {
            try moveToLabel(accountId: accountId, threadId: threadId, labelId: Self.labelID(AppModel.blockedLabel), from: from)
        }
    }

    func unblockSender(accountId: String, address: String, threadId: String?) throws {
        state.withLock { $0.blocked[accountId]?.removeAll { $0.caseInsensitiveCompare(address) == .orderedSame } }
        if let threadId {
            try relabel(accountId: accountId, threadId: threadId, add: [], remove: [Self.labelID(AppModel.blockedLabel)])
            _ = try apply(accountId: accountId, threadId: threadId, action: .moveToInbox)
        }
    }

    func blockedSenders(accountId: String) throws -> [String] {
        _ = try account(accountId)
        return state.withLock { $0.blocked[accountId] ?? [] }
    }

    func moveToInbox(accountId: String, threadId: String, from: Mailbox) throws -> ActionOutcome {
        try apply(accountId: accountId, threadId: threadId, action: .moveToInbox)
    }

    /// A filed thread back in its account's inbox (Move to inbox, Undo).
    private static func backToInbox(_ index: Int, in state: inout State) {
        let thread = state.filed.remove(at: index).thread
        let gmail = state.accounts.first { $0.id == thread.id.account }?.kind == .gmail
        state.items.append(SampleData.Item(thread: thread, category: gmail ? .primary : nil))
    }

    /// Renames (or with nil, takes off) a label on every thread of the account.
    private static func relabelAll(in state: inout State, account: String, _ rename: (String) -> String?) {
        for index in state.items.indices where state.items[index].thread.id.account == account {
            state.items[index].thread.labels = state.items[index].thread.labels.compactMap(rename)
        }
        for index in state.filed.indices where state.filed[index].thread.id.account == account {
            state.filed[index].thread.labels = state.filed[index].thread.labels.compactMap(rename)
        }
    }

    // MARK: Reading

    func cachedThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread? {
        try readThread(accountId: accountId, threadId: threadId)
    }

    func readThread(accountId: String, threadId: String) throws -> NimbraCore.MailThread {
        try state.withLock { state in
            let id = MailThread.ID(account: accountId, thread: threadId)
            if let item = state.items.first(where: { $0.thread.id == id }) {
                return NimbraCore.MailThread(id: threadId, messages: item.thread.messages.map(Self.message))
            }
            // A filed thread (Drafts, Sent, Done) has its summary only: one message from it.
            guard let filed = state.filed.first(where: { $0.thread.id == id }) else { throw NimbraError.NotFound }
            let thread = filed.thread
            let mine = filed.mailbox == .drafts || filed.mailbox == .sent
            let other = thread.sender ?? SampleData.me
            let message = Message(
                from: mine ? SampleData.me : other, to: mine ? [other] : [SampleData.me], date: thread.date,
                body: thread.snippet.hasPrefix("You: ") ? String(thread.snippet.dropFirst(5)) : thread.snippet
            )
            return NimbraCore.MailThread(id: threadId, messages: [Self.message(message)])
        }
    }

    // MARK: Actions

    func apply(accountId: String, threadId: String, action: ThreadAction) throws -> ActionOutcome {
        try state.withLock { state in
            let id = MailThread.ID(account: accountId, thread: threadId)
            if let index = state.items.firstIndex(where: { $0.thread.id == id }) {
                switch action {
                case .markRead: state.items[index].thread.isUnread = false
                case .markUnread: state.items[index].thread.isUnread = true
                case .star: state.items[index].thread.isStarred = true
                case .unstar: state.items[index].thread.isStarred = false
                case .done:
                    state.filed.append(SampleData.Filed(thread: state.items.remove(at: index).thread, mailbox: .done))
                case .trash:
                    state.filed.append(SampleData.Filed(thread: state.items.remove(at: index).thread, mailbox: .trash))
                case .spam:
                    state.filed.append(SampleData.Filed(thread: state.items.remove(at: index).thread, mailbox: .spam))
                case .moveToInbox, .untrash, .notSpam: break
                }
                return .done
            }
            guard let index = state.filed.firstIndex(where: { $0.thread.id == id }) else { throw NimbraError.NotFound }
            switch action {
            case .markRead: state.filed[index].thread.isUnread = false
            case .markUnread: state.filed[index].thread.isUnread = true
            case .star: state.filed[index].thread.isStarred = true
            case .unstar: state.filed[index].thread.isStarred = false
            case .done: state.filed[index].mailbox = .done
            case .trash: state.filed[index].mailbox = .trash
            case .spam: state.filed[index].mailbox = .spam
            case .moveToInbox, .untrash, .notSpam: Self.backToInbox(index, in: &state)
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
