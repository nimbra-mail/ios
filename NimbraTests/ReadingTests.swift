import Foundation
import NimbraCore
import Synchronization
import Testing
import WebKit
@testable import Nimbra

/// Reading: the mail view's hardening, folding, marking read, the thread's actions, files.
@MainActor
struct ReadingTests {
    // MARK: The mail document

    @Test func thePolicyBlocksEverythingRemoteUntilImagesAreAllowed() throws {
        let blocked = MailDocument.html("<p>Hi</p>", images: false)
        #expect(blocked.contains("default-src 'none'"))
        #expect(blocked.contains("img-src data:;"))
        #expect(blocked.contains("form-action 'none'") && blocked.contains("base-uri 'none'"))
        #expect(!blocked.contains("script-src"))
        #expect(blocked.contains("x-dns-prefetch-control\" content=\"off"))
        // The policy comes before the message, which is not wrapped.
        let policy = try #require(blocked.range(of: "Content-Security-Policy"))
        let message = try #require(blocked.range(of: "<p>Hi</p>"))
        #expect(policy.lowerBound < message.lowerBound)
        #expect(!blocked.contains("<body>"))

        // Allowed, images come only through Nimbra's scheme: never straight from the web.
        let allowed = MailDocument.html("<p>Hi</p>", images: true)
        #expect(allowed.contains("img-src data: nimbra-image:;"))
        #expect(!allowed.contains("https:"))
    }

    @Test func linkTagsAreMadeInert() {
        let mail = #"<LINK rel="preconnect" href="https://t.example"><link/><Link\#thref=x><linked>ok</linked><p>link</p>"#
        let inert = MailDocument.withoutLinks(mail)
        #expect(!inert.lowercased().contains("<link "))
        #expect(!inert.lowercased().contains("<link/"))
        #expect(!inert.lowercased().contains("<link\t"))
        #expect(inert.contains("<linked>ok</linked>"))
        #expect(inert.contains("<p>link</p>"))
        #expect(inert.hasPrefix(#"<meta rel="preconnect""#))
        #expect(MailDocument.withoutLinks("Kovač <link>") == "Kovač <meta>")
    }

    @Test func remoteImagesAreFound() {
        #expect(MailDocument.hasRemoteImages(#"<img src="https://a.example/x.png">"#))
        #expect(MailDocument.hasRemoteImages(#"<td background='http://a.example/bg.gif'>"#))
        #expect(MailDocument.hasRemoteImages(#"<div style="background:url( 'https://a.example/x')">"#))
        #expect(!MailDocument.hasRemoteImages(#"<img src="data:image/png;base64,AAAA"><a href="https://a.example">x</a>"#))
    }

    // MARK: Where the mail view may go

    @Test func onlyNimbrasDocumentLoadsAndOnlyTappedWebOrMailLinksLeave() throws {
        let blank = URL(string: "about:blank")
        let web = try #require(URL(string: "https://example.com/a"))
        let mail = try #require(URL(string: "mailto:a@example.com"))
        #expect(MailNavigation.decide(blank, tapped: false, mainFrame: true, pendingLoads: 1) == .load)
        // A document nobody handed it: refused.
        #expect(MailNavigation.decide(blank, tapped: false, mainFrame: true, pendingLoads: 0) == .cancel)
        #expect(MailNavigation.decide(web, tapped: true, mainFrame: true, pendingLoads: 0) == .open(web))
        #expect(MailNavigation.decide(mail, tapped: true, mainFrame: true, pendingLoads: 0) == .open(mail))
        // What the mail starts by itself (a meta refresh, a frame) goes nowhere.
        #expect(MailNavigation.decide(web, tapped: false, mainFrame: true, pendingLoads: 1) == .cancel)
        #expect(MailNavigation.decide(web, tapped: false, mainFrame: false, pendingLoads: 0) == .cancel)
        for link in ["javascript:alert(1)", "file:///etc/hosts", "data:text/html,hi", "tel:123", "nimbra-image:https://a.example/x", "https://"] {
            #expect(MailNavigation.decide(URL(string: link), tapped: true, mainFrame: true, pendingLoads: 0) == .cancel, "\(link)")
        }
        #expect(MailNavigation.decide(nil, tapped: true, mainFrame: true, pendingLoads: 1) == .cancel)
    }

    @Test func theImageSchemeAsksForHttpsImagesOnly() throws {
        let image = try #require(URL(string: "nimbra-image:https://a.example/x.png?s=1"))
        #expect(RemoteImageScheme.remoteURL(image) == "https://a.example/x.png?s=1")
        for link in ["nimbra-image:http://a.example/x.png", "nimbra-image:file:///etc/hosts", "nimbra-image:javascript:1", "https://a.example/x.png", "nimbra-image:https://"] {
            let url = try #require(URL(string: link))
            #expect(RemoteImageScheme.remoteURL(url) == nil, "\(link)")
        }
        #expect(RemoteImageScheme.mimeType(Data([0x89, 0x50, 0x4E, 0x47, 0x0D])) == "image/png")
        #expect(RemoteImageScheme.mimeType(Data([0xFF, 0xD8, 0xFF, 0xE0])) == "image/jpeg")
        #expect(RemoteImageScheme.mimeType(Data("GIF89a".utf8)) == "image/gif")
        #expect(RemoteImageScheme.mimeType(Data("RIFF\u{0}\u{0}\u{0}\u{0}WEBPVP8 ".utf8)) == "image/webp")
        #expect(RemoteImageScheme.mimeType(Data(" <svg xmlns='http://www.w3.org/2000/svg'/>".utf8)) == "image/svg+xml")
        #expect(RemoteImageScheme.mimeType(Data("<html>".utf8)) == "application/octet-stream")
    }

    @Test func theImageSchemeRefusesUntilImagesAreAllowed() async {
        let fetched = Mutex<[String]>([])
        let scheme = RemoteImageScheme { url in
            fetched.withLock { $0.append(url) }
            return Data([0x89, 0x50, 0x4E, 0x47])
        }
        #expect(!scheme.isAllowed)
        let view = WKWebView(frame: .zero, configuration: MailWebConfiguration.make(images: scheme))
        let task = FakeSchemeTask(url: "nimbra-image:https://a.example/x.png")
        scheme.webView(view, start: task)
        #expect(task.failed)
        #expect(fetched.withLock { $0 }.isEmpty)

        scheme.isAllowed = true
        let allowed = FakeSchemeTask(url: "nimbra-image:https://a.example/x.png")
        scheme.webView(view, start: allowed)
        await allowed.waitUntilFinished()
        #expect(allowed.mime == "image/png")
        #expect(fetched.withLock { $0 } == ["https://a.example/x.png"])
    }

    // MARK: The mail view's settings

    @Test func theMailViewRunsNoScriptsFromMailAndKeepsNothing() {
        let scheme = RemoteImageScheme { _ in nil }
        let configuration = MailWebConfiguration.make(images: scheme)
        #expect(!configuration.defaultWebpagePreferences.allowsContentJavaScript)
        #expect(!configuration.websiteDataStore.isPersistent)
        #expect(!configuration.preferences.javaScriptCanOpenWindowsAutomatically)
        #expect(configuration.dataDetectorTypes.isEmpty)
        #expect(!configuration.allowsInlineMediaPlayback)
        #expect(configuration.mediaTypesRequiringUserActionForPlayback == .all)
        #expect(configuration.urlSchemeHandler(forURLScheme: RemoteImageScheme.name) === scheme)

        // Nimbra's own scripts, in its own world: fitting always, images and darkening on request.
        let controller = WKUserContentController()
        MailWebConfiguration.install(on: controller, images: false, darken: false)
        #expect(controller.userScripts.count == 1)
        MailWebConfiguration.install(on: controller, images: true, darken: true)
        #expect(controller.userScripts.count == 3)
        #expect(controller.userScripts.allSatisfy { $0.isForMainFrameOnly })
    }

    @Test func theDarkScriptIsTheMacsWithTheListColour() throws {
        let dark = try #require(MailWebConfiguration.darkScript())
        // bg/list (Dark) is #0E0E14.
        #expect(dark.contains("const SURFACE = [14, 14, 20];"))
        // It only reads computed colours and sets inline ones: no network, no messages out.
        for call in ["fetch(", "XMLHttpRequest", "postMessage", "webkit.messageHandlers", "innerHTML", "location"] {
            #expect(!dark.contains(call), "\(call)")
        }
        // The oklch fix and light boxes on the mail's own dark stay.
        #expect(dark.contains("oklch("))
        #expect(dark.contains("Light on the mail's own dark"))
        for name in ["mail_images", "mail_fit"] {
            let script = try #require(MailWebConfiguration.script(name))
            #expect(!script.contains("fetch(") && !script.contains("innerHTML") && !script.contains("postMessage"))
        }
    }

    @Test func theRuleListCompiles() async {
        #expect(await MailContentRules.list() != nil)
    }

    // MARK: The reader

    @Test func spansAreUTF8OffsetsAndLinksStayWebOrMail() {
        // "Kovač" has a two-byte letter: "wrote" starts at byte 12, not character 11.
        let text = "Mira Kovač wrote here"
        let block = TextBlock(kind: .paragraph, quoteDepth: 0, text: text, spans: [
            TextSpan(start: 12, end: 17, bold: true, italic: false, code: false, link: nil),
            TextSpan(start: 18, end: 22, bold: false, italic: false, code: false, link: "https://example.com"),
            TextSpan(start: 0, end: 4, bold: false, italic: false, code: false, link: "javascript:alert(1)"),
            TextSpan(start: 5, end: 200, bold: true, italic: false, code: false, link: nil),
            TextSpan(start: 9, end: 10, bold: true, italic: false, code: false, link: nil),
        ])
        let attributed = ReaderText.attributed(block)
        #expect(String(attributed.characters) == text)
        let bold = attributed.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }.map { String(attributed[$0.range].characters) }
        #expect(bold == ["wrote"])
        let links = attributed.runs.compactMap { run in run.link.map { ($0, String(attributed[run.range].characters)) } }
        #expect(links.count == 1)
        #expect(links.first?.0 == URL(string: "https://example.com"))
        #expect(links.first?.1 == "here")
    }

    // MARK: Folding

    @Test func earlierMessagesFoldOldestFirstAndOpenOneAtATime() {
        let messages = ["a", "b", "c", "d"].map { Message(id: $0, from: SampleData.mira, to: [], date: .now, body: $0) }
        #expect(Folding.runs(messages, expanded: []).map { $0.map(\.id) } == [["a", "b", "c", "d"]])
        #expect(Folding.runs(messages, expanded: ["b"]).map { $0.map(\.id) } == [["a"], ["b"], ["c", "d"]])
        #expect(Folding.runs(messages, expanded: ["d", "a"]).map { $0.map(\.id) } == [["a"], ["b", "c"], ["d"]])
        #expect(Folding.runs([], expanded: []).isEmpty)
    }

    // MARK: Opening a thread

    @Test func openingReadsTheKeptThreadFirstWithItsHTMLAndFiles() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { state in
            state.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("t1", unread: true)]
            state.kept["t1"] = Self.thread("t1", html: "<p>Hi</p>")
        }
        let app = Fixture.app(engine)
        await app.start()
        await app.open(Nimbra.MailThread.ID(account: "i1", thread: "t1"))

        let opened = app.opened[MailThread.ID(account: "i1", thread: "t1")]
        #expect(opened?.messages.first?.html == "<p>Hi</p>")
        #expect(opened?.messages.first?.unsubscribe == "https://list.example/u")
        #expect(opened?.messages.first?.attachments.first?.attachmentID == "att-1")
        #expect(!engine.calls.contains("read t1"))
        #expect(app.readingOptions.loadImages == false)
    }

    @Test func aThreadThatCannotBeReadSaysSoInPlace() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { $0.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("t1")] }
        let app = Fixture.app(engine)
        await app.start()
        engine.fail("readThread", with: .Offline)
        let id = Nimbra.MailThread.ID(account: "i1", thread: "t1")
        await app.loadMessages(id)
        #expect(app.unreadable.contains(id))
        #expect(app.alert == nil)
        #expect(app.isOffline)

        await app.loadMessages(id)
        #expect(!app.unreadable.contains(id))
        #expect(app.opened[id]?.messages.count == 1)
    }

    @Test func remoteImagesFollowPreferencesInTheOriginalAndAskInTheReader() {
        let app = Fixture.app(FakeEngine())
        let html = Message(id: "h", from: SampleData.mira, to: [], date: .now, body: "", html: "<img src=https://a/x>")
        let plain = Message(id: "p", from: SampleData.mira, to: [], date: .now, body: "")
        app.readingOptions.loadImages = true
        #expect(app.showsOriginal(html) && app.loadsImages(html))
        #expect(!app.loadsImages(plain))
        app.readingOptions.loadImages = false
        #expect(!app.loadsImages(html))
        app.imagesAllowed.insert("h")
        #expect(app.loadsImages(html))
        // Switching one message to the reader, and back.
        app.switchView(html)
        #expect(!app.showsOriginal(html))
        app.switchView(html)
        #expect(app.showsOriginal(html))
        #expect(!app.showsOriginal(plain))
    }

    @Test func remoteImagesComeFromTheEngineOnce() async {
        let engine = FakeEngine()
        let app = Fixture.app(engine)
        #expect(await app.remoteImage("https://a.example/x.png") != nil)
        #expect(await app.remoteImage("https://a.example/x.png") != nil)
        #expect(engine.calls == ["image https://a.example/x.png"])
    }

    // MARK: Marking read

    @Test func markingReadWaitsAsPreferencesSayAndNotAfterLeaving() async throws {
        let (app, engine, id) = await Self.openable(after: 2000)
        let clock = ManualSleep()
        app.readingSleep = { try await clock.sleep($0) }

        let opening = Task { await app.open(id) }
        try await clock.waitForSleeper()
        #expect(clock.requested == [.milliseconds(2000)])
        #expect(app.thread(id)?.isUnread == true)
        clock.wake()
        await opening.value
        #expect(app.thread(id)?.isUnread == false)
        #expect(engine.calls.contains("apply t1 markRead"))

        // Left before the delay: not marked read.
        app.update(id) { $0.isUnread = true }
        let left = Task { await app.open(id) }
        try await clock.waitForSleeper()
        left.cancel()
        await left.value
        #expect(app.thread(id)?.isUnread == true)
    }

    @Test func markedUnreadWhileOpenStaysUnread() async throws {
        let (app, engine, id) = await Self.openable(after: 2000)
        let clock = ManualSleep()
        app.readingSleep = { try await clock.sleep($0) }
        let opening = Task { await app.open(id) }
        try await clock.waitForSleeper()
        await app.keepUnread(id)
        clock.wake()
        await opening.value
        #expect(app.thread(id)?.isUnread == true)
        #expect(!engine.calls.contains("apply t1 markRead"))
    }

    @Test func markingReadAtOnceOrNever() async {
        let (now, nowEngine, id) = await Self.openable(after: 0)
        now.readingSleep = { _ in Issue.record("no wait for at once") }
        await now.open(id)
        #expect(nowEngine.calls.contains("apply t1 markRead"))

        let (never, neverEngine, _) = await Self.openable(after: nil)
        await never.open(id)
        #expect(never.thread(id)?.isUnread == true)
        #expect(!neverEngine.calls.contains { $0.hasPrefix("apply") })
    }

    // MARK: Actions

    @Test func anActionQueuedOfflineStaysShown() async {
        let (app, engine, id) = await Self.openable(after: nil)
        engine.state.withLock { $0.outcome = .queued }
        await app.toggleStar(id)
        #expect(app.thread(id)?.isStarred == true)
        #expect(app.isOffline)
        #expect(app.alert == nil)

        await app.trash(id)
        #expect(app.thread(id) == nil)
        #expect(engine.calls.contains("apply t1 trash"))
    }

    @Test func aRefusedActionIsPutBack() async {
        let (app, engine, id) = await Self.openable(after: nil)
        engine.fail("apply", with: .Failed(message: "No."))
        await app.trash(id)
        #expect(app.thread(id) != nil)
        #expect(app.alert == .failed("No."))
    }

    @Test func moveToInboxRestoresFromTrashAndSpam() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        let app = Fixture.app(engine)
        await app.start()
        let inTrash = Nimbra.MailThread.ID(account: "i1", thread: "x")
        let inSpam = Nimbra.MailThread.ID(account: "i1", thread: "y")
        let archived = Nimbra.MailThread.ID(account: "i1", thread: "z")
        app.listings[ListingKey(account: "i1", mailbox: .trash)] = Listing(threads: [Nimbra.MailThread(row: Fixture.row("x"), account: "i1")])
        app.listings[ListingKey(account: "i1", mailbox: .spam)] = Listing(threads: [Nimbra.MailThread(row: Fixture.row("y"), account: "i1")])
        app.listings[ListingKey(account: "i1", mailbox: .done)] = Listing(threads: [Nimbra.MailThread(row: Fixture.row("z"), account: "i1")])
        #expect(app.outsideInbox(inTrash) == .trash)
        await app.moveToInbox(inTrash)
        await app.moveToInbox(inSpam)
        await app.moveToInbox(archived)
        #expect(engine.calls.suffix(3) == ["moveToInbox x trash", "moveToInbox y spam", "moveToInbox z done"])
        #expect(app.thread(archived) == nil)
    }

    @Test func moveToInboxLeavesOnlyTheListItLeaves() async throws {
        let engine = FakeEngine(accounts: [Fixture.imap])
        let app = Fixture.app(engine)
        await app.start()
        let id = Nimbra.MailThread.ID(account: "i1", thread: "z")
        let thread = Nimbra.MailThread(row: Fixture.row("z"), account: "i1")
        let done = ListingKey(account: "i1", mailbox: .done)
        let starred = ListingKey(account: "i1", mailbox: .starred)
        app.listings[done] = Listing(threads: [thread])
        app.listings[starred] = Listing(threads: [thread])
        let removal = try #require(await app.moveToInbox(id))
        #expect(engine.calls.last == "moveToInbox z done")
        #expect(app.listings[done]?.threads.isEmpty == true)
        #expect(app.listings[starred]?.threads.map(\.id) == [id])
        #expect(app.toast?.text == "Moved to inbox")
        await app.undo(removal)
        #expect(app.listings[done]?.threads.map(\.id) == [id])
    }

    @Test func moveToInboxFromALabelStaysInTheInbox() async {
        let engine = FakeEngine(accounts: [Fixture.imap])
        let app = Fixture.app(engine)
        await app.start()
        let id = Nimbra.MailThread.ID(account: "i1", thread: "z")
        let thread = Nimbra.MailThread(row: Fixture.row("z"), account: "i1")
        let inbox = ListingKey(account: "i1", mailbox: .inbox)
        app.listings[inbox] = Listing(threads: [thread])
        app.listings[ListingKey(account: "i1", mailbox: .label(id: "L1"))] = Listing(threads: [thread])
        await app.moveToInbox(id)
        #expect(engine.calls.last == "moveToInbox z inbox")
        #expect(app.listings[inbox]?.threads.map(\.id) == [id])
    }

    @Test func undoPutsTheThreadBackAndMakesTheInverse() async throws {
        let (app, engine, id) = await Self.openable(after: nil)
        let removal = try #require(await app.trash(id))
        #expect(app.thread(id) == nil)
        #expect(removal.inverse == undoAction(action: .trash))
        await app.undo(removal)
        #expect(app.inboxThreads.map(\.id) == [id])
        #expect(engine.calls.last == "apply t1 \(removal.inverse)")

        // Done's Undo is Move to Inbox; refused, the thread leaves again.
        let done = try #require(await app.markDoneFromThread(id))
        #expect(done.inverse == .moveToInbox)
        engine.fail("apply", with: .Failed(message: "No."))
        await app.undo(done)
        #expect(app.thread(id) == nil)
    }

    @Test func aRefusedRemovalOffersNoUndo() async {
        let (app, engine, id) = await Self.openable(after: nil)
        engine.fail("apply", with: .Failed(message: "No."))
        #expect(await app.markDoneFromThread(id) == nil)
        #expect(app.thread(id) != nil)
    }

    @Test func aThreadInTheInboxIsNotMovedThere() async {
        let (app, _, id) = await Self.openable(after: nil)
        #expect(app.outsideInbox(id) == nil)
    }

    // MARK: Files

    @Test func attachmentsAreWrittenProtectedAndRemovedWithTheThread() async throws {
        let (app, engine, id) = await Self.openable(after: nil)
        engine.state.withLock { $0.files["att-1"] = Data("%PDF".utf8) }
        let attachment = Attachment(name: "../../Plan.pdf", kind: "PDF", size: .init(value: 4, unit: .bytes), messageID: "m1", attachmentID: "att-1")
        let url = try #require(await app.attachmentFile(attachment, in: id))
        #expect(url.lastPathComponent == "Plan.pdf")
        #expect(url.path().hasPrefix(AttachmentFiles.folder(for: id).path()))
        let written = try Data(contentsOf: url)
        #expect(written == Data("%PDF".utf8))
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        #expect(attributes[.posixPermissions] as? Int == 0o600)
        #expect(engine.calls.contains("download m1 att-1"))

        AttachmentFiles.remove(for: id)
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    @Test func attachmentNamesStayInTheirFolder() {
        #expect(AttachmentFiles.safeName("../../etc/passwd") == "passwd")
        #expect(AttachmentFiles.safeName("..") == "Attachment")
        #expect(AttachmentFiles.safeName(".hidden.txt") == "hidden.txt")
        #expect(AttachmentFiles.safeName("a\\b:c.pdf") == "c.pdf")
        #expect(AttachmentFiles.safeName("Q4 plan.pdf") == "Q4 plan.pdf")
        #expect(AttachmentFiles.safeName("") == "Attachment")
    }

    // MARK: Fixtures

    /// An app with one unread thread "t1" in an IMAP inbox, and when it counts as read.
    private static func openable(after ms: UInt32?) async -> (AppModel, FakeEngine, Nimbra.MailThread.ID) {
        let engine = FakeEngine(accounts: [Fixture.imap])
        engine.state.withLock { state in
            state.cached[ListingKey(account: "i1", mailbox: .inbox)] = [Fixture.row("t1", unread: true)]
            state.markReadAfterMs = ms
        }
        let app = Fixture.app(engine)
        await app.start()
        return (app, engine, Nimbra.MailThread.ID(account: "i1", thread: "t1"))
    }

    private static func thread(_ id: String, html: String?) -> NimbraCore.MailThread {
        let message = MailMessage(
            from: NimbraCore.Person(name: "Ana Lima", address: "ana@example.com"), to: [], cc: [], bcc: [], replyTo: nil,
            sender: "Ana Lima", address: "ana@example.com", others: [], messageId: "<m1@example.com>",
            timestampMs: 1_800_000_000_000, snippet: "Hi", blocks: [], text: "Hi", html: html,
            attachments: [AttachmentInfo(messageId: "m1", attachmentId: "att-1", name: "Plan.pdf", mime: "application/pdf", size: 4)],
            unsubscribe: "https://list.example/u"
        )
        return NimbraCore.MailThread(id: id, messages: [message])
    }
}

/// A clock the test moves: `sleep` waits until `wake`, and throws when its task is cancelled.
private nonisolated final class ManualSleep: Sendable {
    private struct State {
        var requested: [Duration] = []
        var waiting: [UUID: CheckedContinuation<Void, any Error>] = [:]
    }

    private let state = Mutex(State())

    var requested: [Duration] { state.withLock { $0.requested } }

    func sleep(_ duration: Duration) async throws {
        let key = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                state.withLock { state in
                    state.requested.append(duration)
                    state.waiting[key] = continuation
                }
            }
        } onCancel: {
            state.withLock { $0.waiting.removeValue(forKey: key) }?.resume(throwing: CancellationError())
        }
    }

    func wake() {
        let waiting = state.withLock { state in
            defer { state.waiting.removeAll() }
            return Array(state.waiting.values)
        }
        waiting.forEach { $0.resume() }
    }

    /// Until something sleeps (a second at most).
    func waitForSleeper() async throws {
        for _ in 0..<200 {
            if state.withLock({ !$0.waiting.isEmpty }) { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("nothing slept")
    }
}

/// A scheme task that records how it was answered.
private final class FakeSchemeTask: NSObject, WKURLSchemeTask {
    let request: URLRequest
    private(set) var failed = false
    private(set) var mime: String?
    private var finished: CheckedContinuation<Void, Never>?
    private var isDone = false

    init(url: String) {
        request = URLRequest(url: URL(string: url)!)
    }

    func didReceive(_ response: URLResponse) { mime = response.mimeType }
    func didReceive(_ data: Data) {}
    func didFinish() { done() }
    func didFailWithError(_ error: any Error) {
        failed = true
        done()
    }

    func waitUntilFinished() async {
        if isDone { return }
        await withCheckedContinuation { finished = $0 }
    }

    private func done() {
        isDone = true
        finished?.resume()
        finished = nil
    }
}
