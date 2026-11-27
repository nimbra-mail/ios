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
        // MARK: Mailboxes
        /// Threads outside the inboxes (Drafts, Sent, Done), each in its mailbox.
        var filed: [SampleData.Filed] = []
        /// Each account's labels by name, in order.
        var labels: [String: [String]] = [:]
        var blocked: [String: [String]] = [:]
    }

    private let state: Mutex<State>
    /// The demo's offline state (`-Offline YES`): sends wait for the connection.
    private let offline: Bool
    // MARK: Settings
    /// Preferences and signatures (`SampleEngine+Settings`).
    let settings = Mutex(SampleSettings())

    init(accounts: [Account] = SampleData.accounts, items: [SampleData.Item] = SampleData.mail(), offline: Bool = false) {
        let ids = Set(accounts.map(\.id))
        state = Mutex(State(
            accounts: accounts, items: items,
            snoozed: SampleData.reminders().filter { ids.contains($0.accountId ?? "") },
            filed: SampleData.filed().filter { ids.contains($0.thread.id.account) },
            labels: SampleData.labels.filter { ids.contains($0.key) },
            blocked: SampleData.blocked.filter { ids.contains($0.key) }
        ))
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

    // MARK: Compose

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
            let snoozed = state.snoozed.filter { $0.accountId == accountId }.map(\.untilMs).min()
            let next = [state.scheduled[accountId]?.map(\.atMs).min(), waiting > 0 ? Date.now.milliseconds + 15_000 : nil, snoozed]
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

    // MARK: Notifications

    func unsnooze(accountId: String, threadId: String) throws {
        state.withLock { $0.snoozed.removeAll { $0.threadId == threadId && $0.accountId == accountId } }
    }

    func wakeDue(accountId: String) throws -> [SnoozedThread] {
        let now = Date.now.milliseconds
        return state.withLock { state in
            let due = state.snoozed.filter { $0.accountId == accountId && $0.untilMs <= now }
            state.snoozed.removeAll { $0.accountId == accountId && $0.untilMs <= now }
            return due
        }
    }

    /// The sample mail gets no new mail.
    func checkForChanges(accountId: String, cursor: String?) throws -> SyncResult {
        SyncResult(cursor: "sample", changedThreads: [], newUnreadInbox: [], named: [], moreNew: 0, notify: true, expired: false)
    }

    func badgeCount() throws -> UInt32 {
        state.withLock { state in UInt32(state.items.count { $0.thread.isUnread }) }
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
