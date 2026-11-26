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
}
