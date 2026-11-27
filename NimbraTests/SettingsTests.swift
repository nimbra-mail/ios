import Foundation
import NimbraCore
import SwiftUI
import Testing
@testable import Nimbra

@MainActor
struct SettingsTests {
    // MARK: Preferences

    @Test func preferencesRoundTripThroughTheEngine() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.state.withLock { $0.preferences.checkEverySeconds = 300 }
        let app = Fixture.app(engine)
        await app.loadPreferences()
        #expect(app.preferences.checkEverySeconds == 300)

        await app.setPreference(\.undoSendSeconds, UndoSendDelay.twenty.rawValue)
        await app.setPreference(\.markRead, .never)
        await app.setPreference(\.loadImages, false)

        let kept = engine.state.withLock { $0.preferences }
        #expect(kept.undoSendSeconds == 20)
        #expect(kept.markRead == .never)
        #expect(!kept.loadImages)
        #expect(kept.checkEverySeconds == 300)
        #expect(app.preferences == kept)
    }

    @Test func aRefusedPreferenceIsPutBackAndSaysWhy() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let app = Fixture.app(engine)
        await app.loadPreferences()
        engine.fail("setPreferences", with: .Failed(message: "Disk full"))
        await app.setPreference(\.badge, false)
        #expect(app.preferences.badge)
        #expect(app.alert != nil)
    }

    @Test func anUnchangedPreferenceIsNotWritten() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let app = Fixture.app(engine)
        await app.loadPreferences()
        await app.setPreference(\.badge, app.preferences.badge)
        #expect(!engine.calls.contains("setPreferences"))
    }

    @Test func aKeptPreferenceTellsNotifications() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.state.withLock { $0.badge = 7 }
        let app = Fixture.app(engine)
        let notifier = app.notifier as! FakeNotifier
        notifier.status = .allowed
        await app.start()
        await app.loadNotificationSettings()
        await app.loadPreferences()
        #expect(notifier.badge == nil)
        await app.setPreference(\.notificationSound, false)
        #expect(notifier.badge == 7)
    }

    @Test func aNewImapPasswordSignsInAgain() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        let app = Fixture.app(engine)
        await app.start()
        app.signedOut.insert("i1")
        engine.fail("updateImapPassword", with: .SignedOut(accountId: "i1"))
        let refused = await app.updateImapPassword("i1", password: "old")
        #expect(refused == String(localized: "The server did not take that password. Check it, or use an app password."))
        #expect(app.signedOut.contains("i1"))
        #expect(app.alert == nil)

        engine.fail("updateImapPassword", with: .NeedsAppPassword(accountId: "i1"))
        let ownPassword = await app.updateImapPassword("i1", password: "google account password")
        #expect(ownPassword == String(localized: "Use an app password from your Google Account, not your Google password."))
        #expect(app.signedOut.contains("i1"))
        #expect(app.alert == nil)

        #expect(await app.updateImapPassword("i1", password: "abcd efgh ijkl mnop") == nil)
        let given = engine.state.withLock { $0.password }
        #expect(given == "abcd efgh ijkl mnop")
        #expect(!app.signedOut.contains("i1"))
        #expect(engine.calls.contains("updateImapPassword i1"))
    }

    @Test func choicesReadStoredSecondsAsTheMacDoes() {
        #expect(CheckInterval(seconds: 15) == .tenSeconds)
        #expect(CheckInterval(seconds: 30) == .thirtySeconds)
        #expect(CheckInterval(seconds: 90) == .oneMinute)
        #expect(CheckInterval(seconds: 600) == .fiveMinutes)
        #expect(UndoSendDelay(seconds: 6) == .five)
        #expect(UndoSendDelay(seconds: 5) == .five)
        #expect(UndoSendDelay(seconds: 0) == .off)
        #expect(UndoSendDelay(seconds: 11) == .ten)
    }

    // MARK: Accounts

    @Test func removingAnAccountKeepsSettingsUpUntilTheLast() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, Fixture.imap])
        let app = Fixture.app(engine)
        await app.start()
        app.showsSettings = true

        #expect(await app.removeAccountInSettings("i1"))
        #expect(app.accounts.map(\.id) == ["g1"])
        #expect(app.showsSettings)
        #expect(app.phase == .signedIn)

        #expect(await app.removeAccountInSettings("g1"))
        #expect(app.accounts.isEmpty)
        #expect(!app.showsSettings)
        #expect(app.phase == .welcome)
        #expect(engine.calls.contains("remove g1"))
    }

    @Test func aRefusedRemovalKeepsTheAccount() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let app = Fixture.app(engine)
        await app.start()
        app.showsSettings = true
        engine.fail("removeAccount", with: .Failed(message: "Keychain"))
        #expect(await !app.removeAccountInSettings("g1"))
        #expect(app.accounts.map(\.id) == ["g1"])
        #expect(app.showsSettings)
        #expect(app.alert != nil)
    }

    @Test func addAccountOpensOnceSettingsHasClosed() {
        let app = Fixture.app(FakeEngine())
        app.showsSettings = true
        app.addAccountFromSettings()
        #expect(!app.showsSettings)
        #expect(app.addingAccount == nil)
        app.settingsClosed()
        #expect(app.addingAccount == .providers)
        app.addingAccount = nil
        app.settingsClosed()
        #expect(app.addingAccount == nil)
    }

    // MARK: Signatures

    @Test func signaturesAreAddedChangedMadeDefaultAndDeleted() async throws {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let app = Fixture.app(engine)
        await app.start()

        #expect(await app.saveSignature(nil, account: "g1", name: "Work", html: "<div>Ana</div>", isDefault: true))
        var work = try #require(app.signatures["g1"]?.first)
        #expect(work.name == "Work")
        #expect(work.html == "<div>Ana</div>")
        #expect(work.isDefault)

        #expect(await app.saveSignature(nil, account: "g1", name: "Short", html: "<div>A</div>", isDefault: true))
        let short = try #require(app.signatures["g1"]?.first { $0.name == "Short" })
        work = try #require(app.signatures["g1"]?.first { $0.name == "Work" })
        #expect(short.isDefault)
        #expect(!work.isDefault)

        #expect(await app.saveSignature(short.id, account: "g1", name: "Short", html: "<div>B</div>", isDefault: false))
        #expect(engine.calls.contains("setDefaultSignature g1 none"))
        #expect(app.signatures["g1"]?.contains { $0.isDefault } == false)
        #expect(app.signatures["g1"]?.first { $0.id == short.id }?.html == "<div>B</div>")

        #expect(await app.deleteSignature(work))
        #expect(app.signatures["g1"]?.map(\.name) == ["Short"])
    }

    @Test func aRefusedSignatureSaysWhy() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let app = Fixture.app(engine)
        await app.start()
        engine.fail("addSignature", with: .Invalid(message: "An account can have 20 signatures."))
        #expect(await !app.saveSignature(nil, account: "g1", name: "Too many", html: "", isDefault: false))
        #expect(app.signatures["g1"]?.isEmpty == true)
        #expect(app.alert != nil)
    }

    // MARK: Signature HTML

    @Test func formattedTextBecomesHTMLAndBack() {
        let font = NimbraTextStyle.reading.font
        let html = #"<div>Ana <b>Lima</b></div><div><br></div><div><a href="https://nimbra.me">nimbra.me</a> &amp; <i>more</i> <u>here</u></div>"#
        let parsed = SignatureHTML.text(from: html, font: font)
        #expect(parsed.isComplete)
        #expect(String(parsed.text.characters) == "Ana Lima\n\nnimbra.me & more here")

        let back = SignatureHTML.html(from: parsed.text, context: EnvironmentValues().fontResolutionContext)
        #expect(back == html)
    }

    @Test func htmlTheTextEditorCannotKeepIsSaidSo() {
        let font = NimbraTextStyle.reading.font
        #expect(!SignatureHTML.text(from: #"<div><img src="https://x.y/a.png" alt="Logo"></div>"#, font: font).isComplete)
        #expect(!SignatureHTML.text(from: "<ul><li>One</li></ul>", font: font).isComplete)
        let preview = SignatureHTML.text(from: #"<div>Hi</div><img src="https://x.y/a.png" alt="Logo">"#, font: font, preview: true)
        #expect(String(preview.text.characters) == "Hi\nImage: Logo")
    }

    @Test func scriptsAndUnsafeLinksAreLeftOut() {
        let font = NimbraTextStyle.reading.font
        let parsed = SignatureHTML.text(from: #"<div><script>alert(1)</script><a href="javascript:alert(1)">x</a> &lt;b&gt;</div>"#, font: font)
        #expect(String(parsed.text.characters) == "x <b>")
        #expect(parsed.text.runs.allSatisfy { $0.link == nil })
        let back = SignatureHTML.html(from: parsed.text, context: EnvironmentValues().fontResolutionContext)
        #expect(back == "<div>x &lt;b&gt;</div>")
    }

    @Test func typedLinksGetASafeScheme() {
        #expect(SignatureHTML.link(from: "nimbra.me")?.absoluteString == "https://nimbra.me")
        #expect(SignatureHTML.link(from: "ana@example.org")?.absoluteString == "mailto:ana@example.org")
        #expect(SignatureHTML.link(from: "http://a.b")?.absoluteString == "http://a.b")
        #expect(SignatureHTML.link(from: "javascript:alert(1)") == nil)
        #expect(SignatureHTML.link(from: "  ") == nil)
    }
}
