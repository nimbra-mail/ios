import Foundation
import NimbraCore
import Observation

/// The app's state, on the mail engine: who is signed in, the listings shown, their
/// counts, and how the connection is. One per app, in the environment.
///
/// Areas live in their own files as extensions: accounts and sign-in
/// (`AppModel+Accounts`), mailboxes and the inbox (`AppModel+Mailboxes`), thread actions
/// (`AppModel+Actions`), reading (`AppModel+Reading`) and staying current
/// (`AppModel+Refresh`). A new area adds its file the same way, and its stored state
/// here (an extension cannot store). `docs/architecture.md` has the layers.
@Observable
final class AppModel {
    enum Phase: Equatable {
        /// The engine is opening (the Keychain, the store).
        case launching
        /// No account on this device yet.
        case welcome
        case signedIn
    }

    var phase: Phase = .launching

    // MARK: Accounts

    /// The accounts on this device, in the engine's order.
    var accounts: [Account] = []
    /// The account the inbox shows.
    var accountID: Account.ID?
    /// Accounts whose sign-in is gone (`MailError.signedOut`): they need signing in again.
    var signedOut: Set<Account.ID> = []
    /// A sign-in is under way (the provider's page, then the engine finishing it).
    var isSigningIn = false

    // MARK: Mailboxes

    /// The split inbox category shown, for an account that has the split inbox.
    var split: SplitCategory = .primary
    /// The listings loaded so far, by account and mailbox.
    var listings: [ListingKey: Listing] = [:]
    /// Each account's mailboxes in order, as the engine lists them.
    var mailboxes: [Account.ID: [MailboxEntry]] = [:]
    /// Unread threads by account, then label id ("INBOX", "CATEGORY_PERSONAL", a label's id).
    var unread: [Account.ID: [String: Int]] = [:]
    /// Threads snoozed or set as reminders, by account, soonest first.
    var snoozedThreads: [Account.ID: [MailThread]] = [:]
    /// Threads opened in full (their messages read), by id.
    var opened: [MailThread.ID: MailThread] = [:]
    /// The last search's results.
    var searchResults: [MailThread] = []
    var isSearching = false
    /// The add-account sheet, while it is up.
    var addingAccount: AddAccountStart?

    // MARK: Compose

    /// The message being written, while the composer is up (`AppModel+Compose`).
    var composer: Composer?
    /// The toast floating over the tab bar (Undo send, offline, sent), while it is up.
    var toast: Toast?
    /// The undo the toast up offers (`show(_:undo:)`), by its action's id.
    @ObservationIgnored var toastUndos: [UUID: @MainActor () async -> Void] = [:]
    /// Pending draft saves, by composer (debounced; `AppModel+Compose`).
    @ObservationIgnored var draftSaves: [Composer.ID: Task<Void, Never>] = [:]
    /// The time, and waiting: the system's, or a test's.
    @ObservationIgnored var clock: AppClock = .system

    // MARK: Sending

    /// Messages on their way: held for their undo time, then handed to the server
    /// (`AppModel+Sending`).
    var outbox: [OutboxItem] = []
    /// Messages waiting for the connection, by account (the engine's `pending_work`).
    var waitingMessages: [Account.ID: Int] = [:]
    /// Changes (Done, star…) waiting for the connection, by account.
    var queuedChanges: [Account.ID: Int] = [:]
    /// Send later, by account, soonest first.
    var scheduledSends: [Account.ID: [ScheduledSend]] = [:]
    /// Accounts whose earlier run's unsent mail was picked up (`unsent`) in this run.
    @ObservationIgnored var pickedUp: Set<Account.ID> = []

    // MARK: Connection

    /// The last engine call could not reach a server. Cleared by the next that does.
    var isOffline = false
    /// What a person did that did not work, for an alert.
    var alert: MailError?

    /// The engine, once it is open. Set once, by `start`.
    @ObservationIgnored private(set) var host: EngineHost?
    /// Makes the engine at launch: the real one, or the sample one for the demo.
    @ObservationIgnored private let makeHost: @Sendable () async throws(MailError) -> EngineHost

    /// An app on the real engine, opened by `start`.
    init() {
        makeHost = { () async throws(MailError) -> EngineHost in try await EngineHost.start() }
    }

    /// An app on an engine already made (`SampleEngine`, a test's fake).
    init(host: EngineHost) {
        self.host = host
        makeHost = { host }
    }

    /// The sample mail, signed in or at Welcome: previews and the demo launch.
    static func sample(signedIn: Bool = true, offline: Bool = false) -> AppModel {
        let engine = SampleEngine(accounts: signedIn ? SampleData.accounts : [], offline: offline)
        let app = AppModel(host: EngineHost(engine: engine, oauth: .bundled))
        app.phase = signedIn ? .signedIn : .welcome
        if signedIn { app.accountID = SampleData.work.id }
        return app
    }

    /// Opens the engine, lists the accounts and shows the inbox from the device, then
    /// brings it up to date.
    func start() async {
        if host == nil {
            do throws(MailError) {
                host = try await makeHost()
            } catch {
                alert = error
                phase = .welcome
                return
            }
        }
        await reloadAccounts()
        phase = accounts.isEmpty ? .welcome : .signedIn
        await showInbox()
    }

    /// Runs engine calls for an account; a failure updates the connection state and the
    /// accounts that need signing in again (`handle`). `report` shows a failure in an
    /// alert: for what a person did, not for background refreshes. Nil when it failed.
    /// A call that reached the server says so with `reached`.
    @discardableResult
    func engine<T: Sendable>(
        for account: Account.ID? = nil,
        report: Bool = false,
        work: @escaping @Sendable (any MailEngine) throws -> T
    ) async -> T? {
        guard let host else { return nil }
        do throws(MailError) {
            return try await host.call(work)
        } catch {
            handle(error, account: account, report: report)
            return nil
        }
    }

    /// A call reached the account's server: online, and signed in.
    func reached(_ account: Account.ID) {
        isOffline = false
        signedOut.remove(account)
    }

    /// Takes a failure in: the connection, a sign-in that is gone, or an alert.
    func handle(_ error: MailError, account: Account.ID?, report: Bool) {
        switch error {
        case .offline:
            isOffline = true
            // Offline is shown as a state, never as an alert.
            return
        case .signedOut(let id):
            signedOut.insert(accounts.contains { $0.id == id } ? id : account ?? id)
        default:
            break
        }
        if report { alert = error }
    }
}

/// A mailbox of an account.
nonisolated struct ListingKey: Hashable, Sendable {
    let account: Account.ID
    let mailbox: Mailbox
}

/// A mailbox's threads as far as they are listed.
nonisolated struct Listing: Equatable, Sendable {
    var threads: [MailThread] = []
    /// Where the next page starts, when there is one (`loadMore`).
    var nextPage: String?
    /// Brought up to date at least once since launch.
    var isFresh = false
    var isRefreshing = false
    var isLoadingMore = false
}
