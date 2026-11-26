import Foundation
import NimbraCore
import Testing

/// The Rust mail engine is linked in and answers: calls that need no account or network.
struct CoreTests {
    private static let sample = Data("""
        From: Ana Lima <ana@example.com>\r
        To: Ben <ben@example.org>\r
        Subject: Lunch\r
        Date: Tue, 3 Nov 2026 10:00:00 +0000\r
        Message-ID: <lunch-1@example.com>\r
        MIME-Version: 1.0\r
        Content-Type: text/plain; charset=utf-8\r
        \r
        Friday at noon?\r

        """.utf8)

    @Test func parsesARawMessage() throws {
        let message = try #require(parseMessage(raw: Self.sample))
        #expect(message.from.address == "ana@example.com")
        #expect(message.from.name == "Ana Lima")
        #expect(message.to.map(\.address) == ["ben@example.org"])
        #expect(message.messageId == "<lunch-1@example.com>")
        #expect(message.text.contains("Friday at noon?"))
        #expect(message.attachments.isEmpty)
    }

    @Test func refusesWhatIsNotAMessage() {
        #expect(parseMessage(raw: Data()) == nil)
    }

    @Test func findsWellKnownProvidersOffline() throws {
        guard case .needsOAuth(let provider) = try #require(knownServers(email: "someone@gmail.com")) else {
            Issue.record("Gmail should need Google's sign-in")
            return
        }
        #expect(provider == "Google")
        #expect(knownServers(email: "someone@example.invalid") == nil)
    }

    @Test func undoesDoneAndStar() {
        #expect(undoAction(action: .done) == .moveToInbox)
        #expect(undoAction(action: .star) == .unstar)
        #expect(undoAction(action: .markRead) == nil)
    }

    @Test func checksAddresses() {
        #expect(isEmailAddress(text: "ana@example.com"))
        #expect(!isEmailAddress(text: "ana at example"))
        #expect(!coreVersion().isEmpty)
    }

    @Test func aNewEngineListsNothingAndKeepsPreferences() throws {
        let engine = try TestEngine.shared()
        #expect(engine.accounts().isEmpty)
        #expect(try engine.cachedAllInboxes().isEmpty)
        let all = try engine.allInboxes(perAccount: 0)
        #expect(all.threads.isEmpty && all.failedAccounts == 0)
        var preferences = engine.preferences()
        preferences.undoSendSeconds = 10
        try engine.setPreferences(preferences: preferences)
        #expect(engine.preferences().undoSendSeconds == 10)
    }

    @Test func offersSnoozeAndSendLaterTimesAhead() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let snooze = snoozeTimes()
        #expect(snooze.count >= 6)
        #expect(snooze.allSatisfy { $0.untilMs > now })
        #expect(snooze.filter(\.onlyIfNoReply).count == 2)
        #expect(sendLaterTimes().first?.kind == .inAnHour)
        #expect(parseTime(text: "430p") == TimeOfDay(hour: 16, minute: 30))
        #expect(parseTime(text: "soon") == nil)
        #expect(dayTime(year: 2000, month: 1, day: 1, time: TimeOfDay(hour: 9, minute: 0)) == nil)
    }

    @Test func sendsTheSignatureApartAndFindsItInADraft() {
        let html = messageHtml(
            written: "<div>Hi</div>",
            signature: "<b>Luan</b>",
            quoted: "On Tue, Ana wrote:\n> old"
        )
        let parts = splitDraftHtml(html: html)
        #expect(parts.signature == "<b>Luan</b>")
        #expect(parts.written.contains("Hi") && !parts.written.contains("old"))
        #expect(textToHtml(text: "a<b") == "<div>a&lt;b</div>")
    }

    @Test func readsLinksAsTheMacDoes() {
        let draft = parseMailto(link: "mailto:ana@example.com?subject=Hi")
        #expect(draft?.to == ["ana@example.com"])
        #expect(draft?.subject == "Hi")
        guard case .web(let url) = unsubscribeAction(link: "https://example.com/leave") else {
            Issue.record("an https link opens in the browser")
            return
        }
        #expect(url == "https://example.com/leave")
        #expect(unsubscribeAction(link: "javascript:alert(1)") == nil)
        #expect(contactScanPauseSeconds() == 15)
    }

    @Test func refusesAnAccountItDoesNotHave() throws {
        let engine = try TestEngine.shared()
        #expect(throws: NimbraError.self) { try engine.mailboxes(accountId: "nobody") }
        #expect(throws: NimbraError.self) {
            try engine.cachedThreads(accountId: "nobody", mailbox: .split(category: .primary))
        }
    }
}

/// One engine for the test process (its folders are set once per process), in a fresh
/// temporary folder and with a Keychain in memory: tests never touch the real ones.
nonisolated enum TestEngine {
    private static let made: Result<Engine, Error> = Result {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nimbra-tests-\(UUID().uuidString)", isDirectory: true)
        return try Engine(
            config: EngineConfig(googleClientId: nil, googleClientSecret: nil, microsoftClientId: nil),
            dataDir: root.appendingPathComponent("data").path,
            cacheDir: root.appendingPathComponent("cache").path,
            secrets: MemoryKeychain()
        )
    }

    static func shared() throws -> Engine {
        try made.get()
    }
}

/// A Keychain in memory, for tests.
nonisolated final class MemoryKeychain: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]

    func get(service: String, account: String) throws -> Data {
        try lock.withLock {
            guard let item = items["\(service)/\(account)"] else { throw SecretError.NotFound }
            return item
        }
    }

    func set(service: String, account: String, secret: Data) throws {
        lock.withLock { items["\(service)/\(account)"] = secret }
    }

    func delete(service: String, account: String) throws {
        try lock.withLock {
            guard items.removeValue(forKey: "\(service)/\(account)") != nil else {
                throw SecretError.NotFound
            }
        }
    }
}
