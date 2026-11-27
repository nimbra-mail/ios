import Foundation
import NimbraCore
import Testing
@testable import Nimbra

@MainActor
struct ImapSetupTests {
    private func filled() -> ImapSetup {
        let setup = ImapSetup()
        setup.email = "ana@example.org"
        setup.password = "app-password"
        return setup
    }

    @Test func needsAnAddressAndAPassword() {
        let setup = ImapSetup()
        #expect(!setup.canSubmit)
        setup.email = "ana at example"
        setup.password = "x"
        #expect(!setup.canSubmit)
        setup.email = "ana@example.org"
        #expect(setup.canSubmit)
    }

    @Test func foundServersAreUsedAtOnce() async {
        let engine = FakeEngine()
        let servers = MailServers(
            username: "ana@example.org",
            imap: MailServer(host: "imap.example.org", port: 993, security: .tls),
            smtp: MailServer(host: "smtp.example.org", port: 587, security: .startTls)
        )
        engine.state.withLock { $0.discovery = .servers(servers: servers) }
        let app = Fixture.app(engine)
        await app.start()
        let setup = filled()
        await setup.submit(with: app)
        #expect(setup.isDone)
        #expect(engine.calls.contains("addImap ana@example.org imap.example.org:993 smtp.example.org:587 ana@example.org"))
        #expect(app.phase == .signedIn)
    }

    @Test func unknownServersAreTypedIn() async {
        let engine = FakeEngine()
        let app = Fixture.app(engine)
        await app.start()
        let setup = filled()
        await setup.submit(with: app)
        #expect(setup.step == .servers)
        #expect(setup.notice == .notFound)
        #expect(setup.incoming.suggestion == "imap.example.org")
        #expect(setup.servers.imap.host == "imap.example.org")
        #expect(setup.servers.smtp.port == 465)
        #expect(setup.servers.username == "ana@example.org")

        setup.username = "ana"
        setup.outgoing.host = "mail.example.org"
        setup.outgoing.security = .startTls
        await setup.submit(with: app)
        #expect(engine.calls.contains("addImap ana@example.org imap.example.org:993 mail.example.org:587 ana"))
        #expect(setup.isDone)
    }

    @Test func aRefusedPasswordSaysSo() async {
        let engine = FakeEngine()
        engine.state.withLock { $0.discovery = .servers(servers: MailServers(
            username: "ana@example.org",
            imap: MailServer(host: "imap.example.org", port: 993, security: .tls),
            smtp: MailServer(host: "smtp.example.org", port: 465, security: .tls)
        )) }
        engine.fail("addImapAccount", with: .SignedOut(accountId: nil))
        let app = Fixture.app(engine)
        await app.start()
        let setup = filled()
        await setup.submit(with: app)
        #expect(!setup.isDone)
        #expect(setup.step == .form)
        #expect(setup.notice == .refused(String(localized: "The server did not take that password. Check it, or use an app password.")))
    }

    @Test func aGoogleAddressTakesAnAppPassword() async {
        let engine = FakeEngine()
        engine.state.withLock { $0.discovery = .google(servers: MailServers(
            username: "ana@gmail.com",
            imap: MailServer(host: "imap.gmail.com", port: 993, security: .tls),
            smtp: MailServer(host: "smtp.gmail.com", port: 465, security: .tls)
        )) }
        engine.fail("addImapAccount", with: .NeedsAppPassword(accountId: nil))
        let app = Fixture.app(engine)
        await app.start()
        let setup = ImapSetup()
        setup.email = " ana@gmail.com "
        setup.password = "google account password"
        await setup.submit(with: app)
        #expect(!setup.isDone)
        #expect(setup.step == .form)
        #expect(setup.notice == .refused(String(localized: "Use an app password from your Google Account, not your Google password.")))

        // As Google shows it: the engine takes the spaces out, not the app.
        setup.password = "abcd efgh ijkl mnop"
        await setup.submit(with: app)
        #expect(setup.isDone)
        #expect(engine.calls.contains("addImap ana@gmail.com imap.gmail.com:993 smtp.gmail.com:465 ana@gmail.com"))
        let given = engine.state.withLock { $0.password }
        #expect(given == "abcd efgh ijkl mnop")
        #expect(app.phase == .signedIn)
    }

    @Test func microsoftGoesBackToItsSignIn() async {
        let engine = FakeEngine()
        engine.state.withLock { $0.discovery = .needsOAuth(provider: "Microsoft") }
        let app = Fixture.app(engine)
        await app.start()
        let setup = filled()
        setup.email = "ana@outlook.com"
        await setup.submit(with: app)
        #expect(setup.notice == .failed(String(localized: "This address signs in with Microsoft. Go back and choose Continue with Microsoft.")))
        #expect(!engine.calls.contains { $0.hasPrefix("addImap") })
    }

    @Test func securityMovesTheUsualPortAlong() {
        var server = ServerFields(.imap)
        #expect(server.port == 993)
        server.security = .startTls
        #expect(server.port == 143)
        server.port = 1143
        server.security = .tls
        #expect(server.port == 1143)
    }
}
