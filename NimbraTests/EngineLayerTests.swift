import Foundation
import NimbraCore
import Testing
@testable import Nimbra

struct MailErrorTests {
    @Test(arguments: [
        (NimbraError.SignedOut(account: "a1"), MailError.signedOut(accountID: "a1")),
        (.Offline, .offline),
        (.NotFound, .notFound),
        (.HistoryExpired, .historyExpired),
        (.NeedsFullAccess, .needsFullAccess),
        (.Keychain(message: "item locked"), .keychain),
        (.Invalid(message: "That is not an email address."), .invalid("That is not an email address.")),
        (.Failed(message: "The server closed the connection."), .failed("The server closed the connection.")),
    ])
    func mapsTheEnginesErrors(engine: NimbraError, app: MailError) {
        #expect(MailError(engine) == app)
    }

    @Test func keepsItsOwnAndHidesTheRest() {
        #expect(MailError(MailError.notConfigured(.microsoft)) == .notConfigured(.microsoft))
        guard case .failed = MailError(CocoaError(.fileNoSuchFile)) else {
            Issue.record("an unknown error is a plain failure")
            return
        }
    }

    @Test func theKeychainsWordsAreNeverShown() {
        #expect(!MailError(NimbraError.Keychain(message: "secret detail")).message.contains("secret detail"))
    }
}

struct OAuthConfigTests {
    @Test func takesWellFormedIdsAndMakesTheRedirects() {
        let config = Fixture.oauth
        #expect(config.redirect(for: .google) == OAuthRedirect(
            scheme: "com.googleusercontent.apps.1234-abc",
            uri: "com.googleusercontent.apps.1234-abc:/oauth2redirect"
        ))
        #expect(config.redirect(for: .microsoft) == OAuthRedirect(scheme: "msauth.com.riangle.nimbra", uri: "msauth.com.riangle.nimbra://auth"))
        #expect(config.engineConfig.googleClientSecret == nil)
    }

    @Test(arguments: ["", "   ", "abc", "1234.apps.googleusercontent.com.evil", "$(GOOGLE_IOS_CLIENT_ID)", "a b.apps.googleusercontent.com"])
    func leavesGoogleOffForABadId(id: String) {
        let config = OAuthConfig(googleClientID: id, microsoftClientID: nil, bundleID: "com.riangle.nimbra")
        #expect(config.googleClientID == nil)
        #expect(config.redirect(for: .google) == nil)
    }

    @Test func leavesMicrosoftOffForAnIdThatIsNotAGUID() {
        let config = OAuthConfig(googleClientID: nil, microsoftClientID: "not-a-guid", bundleID: "com.riangle.nimbra")
        #expect(config.redirect(for: .microsoft) == nil)
        #expect(config.engineConfig.microsoftClientId == nil)
    }
}

struct KeychainSecretStoreTests {
    /// Items of their own, apart from the app's.
    private let store = KeychainSecretStore(service: "com.riangle.nimbra.tests.\(UUID().uuidString)")

    @Test func keepsReplacesAndDeletesASecret() throws {
        let first = Data("first".utf8)
        try store.set(service: "nimbra", account: "a1", secret: first)
        #expect(try store.get(service: "nimbra", account: "a1") == first)
        let second = Data("second".utf8)
        try store.set(service: "nimbra", account: "a1", secret: second)
        #expect(try store.get(service: "nimbra", account: "a1") == second)
        try store.delete(service: "nimbra", account: "a1")
        #expect(throws: SecretError.NotFound) { try store.get(service: "nimbra", account: "a1") }
    }

    @Test func tellsAMissingItemFromAFailure() throws {
        #expect(throws: SecretError.NotFound) { try store.get(service: "nimbra", account: "nobody") }
        #expect(throws: SecretError.NotFound) { try store.delete(service: "nimbra", account: "nobody") }
    }

    @Test func keepsTheEnginesServicesApart() throws {
        try store.set(service: "nimbra", account: "a1", secret: Data("one".utf8))
        try store.set(service: "other", account: "a1", secret: Data("two".utf8))
        #expect(try store.get(service: "nimbra", account: "a1") == Data("one".utf8))
        #expect(try store.get(service: "other", account: "a1") == Data("two".utf8))
        try store.delete(service: "nimbra", account: "a1")
        try store.delete(service: "other", account: "a1")
    }
}

struct DNSResolverTests {
    private func parse(_ bytes: [UInt8]) -> MxRecord? {
        bytes.withUnsafeBytes { MXRecordData.parse($0) }
    }

    @Test func readsAnMXRecord() {
        let bytes: [UInt8] = [0, 10, 2] + Array("mx".utf8) + [7] + Array("example".utf8) + [3] + Array("com".utf8) + [0]
        #expect(parse(bytes) == MxRecord(preference: 10, host: "mx.example.com"))
    }

    @Test func refusesWhatItCannotRead() {
        #expect(parse([0, 10]) == nil)
        // The null MX (no mail here) has no host.
        #expect(parse([0, 0, 0]) == nil)
        // A compression pointer, and a label running past the end.
        #expect(parse([0, 10, 0xC0, 0x0C]) == nil)
        #expect(parse([0, 10, 9, 0x6D, 0x78]) == nil)
    }
}

struct EngineFoldersTests {
    @Test func makesBothFoldersAndKeepsMailOutOfBackups() throws {
        let root = URL.temporaryDirectory.appending(path: "nimbra-folders-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let folders = EngineFolders(data: root.appending(path: "data"), cache: root.appending(path: "cache"))
        try folders.prepare()
        let values = try folders.data.resourceValues(forKeys: [.isExcludedFromBackupKey, .isDirectoryKey])
        #expect(values.isDirectory == true)
        #expect(values.isExcludedFromBackup == true)
        #if !targetEnvironment(simulator)
        // The simulator has no Data Protection: checked on a device only.
        let attributes = try FileManager.default.attributesOfItem(atPath: folders.data.path(percentEncoded: false))
        #expect(attributes[.protectionKey] as? FileProtectionType == .completeUntilFirstUserAuthentication)
        #endif
        #expect(FileManager.default.fileExists(atPath: folders.cache.path(percentEncoded: false)))
    }
}
