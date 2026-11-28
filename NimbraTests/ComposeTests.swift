import Foundation
import NimbraCore
import Testing
@testable import Nimbra

/// Writing: the HTML the engine builds and takes apart, addresses as chips, drafts that
/// save themselves, answers, drafts reopened and `mailto:` links. No network.
@MainActor
struct ComposeTests {
    // MARK: HTML

    @Test func aDraftsHtmlComesBackAsItWasWritten() {
        let written = "<div>Looks <b>great</b>, signing off.</div><div><ul><li>Slide 14</li></ul></div>"
        let signature = "<div>Luan Gjokaj</div><div>nimbra.me</div>"
        let html = messageHtml(written: written, signature: signature, quoted: "On Nov 26, Mira wrote:\n\nHi")
        let parts = splitDraftHtml(html: html)
        #expect(Composer.unwrapped(parts.written) == written)
        #expect(parts.signature == signature)

        let draft = DraftMessage(
            id: "d1", to: "mira@northwind.studio, Jonah <jonah@northwind.studio>", cc: "", bcc: "ana@northwind.studio",
            subject: "Re: Q4", body: "", quoted: "On Nov 26, Mira wrote:\n\nHi", html: html, attachments: [], reply: nil
        )
        let composer = Composer(draft: draft, from: "g1")
        #expect(composer.written == written)
        #expect(composer.signature?.html == signature)
        #expect(composer.quoted == "On Nov 26, Mira wrote:\n\nHi")
        #expect(composer.to == ["mira@northwind.studio", "jonah@northwind.studio"])
        #expect(composer.bcc == ["ana@northwind.studio"])
        #expect(composer.showsCcBcc)
        #expect(composer.draftID == "d1")
    }

    @Test func savingAndReopeningAgainAndAgainChangesNothing() {
        var written = "<div>One</div><div><br></div><div>Two</div>"
        for _ in 0..<3 {
            let html = messageHtml(written: written, signature: "<div>S</div>", quoted: "On Mon, A wrote:\n\nHi")
            written = Composer.unwrapped(splitDraftHtml(html: html).written)
        }
        #expect(written == "<div>One</div><div><br></div><div>Two</div>")
        // Without a quote, too; and a wrapper that is not one element stays.
        let plain = messageHtml(written: "<div>A</div>", signature: nil, quoted: nil)
        #expect(Composer.unwrapped(splitDraftHtml(html: plain).written) == "<div>A</div>")
        #expect(Composer.unwrapped("<div dir=\"ltr\">A</div><div>B</div>") == "<div dir=\"ltr\">A</div><div>B</div>")
    }

    @Test func aPlainDraftOpensAsTheEditorsLines() {
        let draft = DraftMessage(
            id: "d2", to: "", cc: "", bcc: "", subject: "", body: "One\nTwo <3", quoted: nil, html: nil, attachments: [], reply: nil
        )
        let composer = Composer(draft: draft, from: "g1")
        #expect(composer.written == textToHtml(text: "One\nTwo <3"))
        #expect(composer.written.contains("&lt;3"))
        #expect(composer.signature == nil)
    }

    @Test func theTextPartHasTheSignatureAfterDashesThenTheQuote() {
        let composer = Composer(kind: .reply, from: "g1")
        composer.text = "Thanks!\n"
        composer.signature = .init(id: "s1", html: "<div>Luan</div>")
        composer.signatureText = "Luan"
        composer.quoted = "On Nov 26, Mira wrote:\n\nHi"
        composer.to = ["mira@northwind.studio"]
        composer.typingTo = "ben@example.com"
        let message = composer.outgoing
        #expect(message.body == "Thanks!\n\n-- \nLuan\n\nOn Nov 26, Mira wrote:\n\nHi")
        #expect(message.to == "mira@northwind.studio, ben@example.com")
        #expect(message.html?.contains("Luan") == true)
    }

    // MARK: Addresses

    @Test func aCommaOrSemicolonFinishesAnAddress() {
        var found = Recipients.chipify("mira@northwind.studio, jo", into: [], all: false)
        #expect(found.chips == ["mira@northwind.studio"])
        #expect(found.rest == "jo")

        found = Recipients.chipify("Jonah Reyes <jonah@northwind.studio>; MIRA@northwind.studio;", into: ["mira@northwind.studio"], all: false)
        #expect(found.chips == ["mira@northwind.studio", "jonah@northwind.studio"])
        #expect(found.rest.isEmpty)

        found = Recipients.chipify("not an address, ana@northwind.studio", into: [], all: true)
        #expect(found.chips == ["ana@northwind.studio"])
        #expect(found.rest == "not an address")
    }

    @Test func pickingASuggestionReplacesWhatWasTyped() {
        let composer = Composer(kind: .new, from: "g1")
        composer.typingTo = "jo"
        composer.add("jonah@northwind.studio", to: .to)
        composer.typingTo = "jon"
        composer.add("JONAH@northwind.studio", to: .to)
        #expect(composer.to == ["jonah@northwind.studio"])
        #expect(composer.typingTo.isEmpty)
    }

    @Test func suggestionsLeaveOutWhoIsAlreadyThere() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.state.withLock {
            $0.contacts = [.init(name: "Jonah Reyes", address: "jonah@northwind.studio"), .init(name: "Joana Silva", address: "joana@riangle.com")]
        }
        let app = Fixture.app(engine)
        await app.start()
        let composer = Composer(kind: .new, from: "g1")
        composer.to = ["jonah@northwind.studio"]
        let people = await app.suggestions(for: "jo", in: composer)
        #expect(people.map(\.email) == ["joana@riangle.com"])
        #expect(await app.suggestions(for: "  ", in: composer).isEmpty)
    }

    // MARK: Drafts

    @Test func aDraftSavesOnceTypingPauses() async {
        let (app, engine, clock) = await started()
        let composer = Composer(kind: .new, from: "g1")
        composer.to = ["mira@northwind.studio"]
        app.composerChanged(composer)
        app.composerChanged(composer)
        app.composerChanged(composer)
        #expect(await eventually { clock.sleeping == 1 })
        #expect(!engine.calls.contains { $0.hasPrefix("saveDraft") })

        clock.advance(by: .milliseconds(2500))
        #expect(await eventually { composer.draftID == "d1" })
        #expect(engine.calls.filter { $0.hasPrefix("saveDraft") } == ["saveDraft g1 new"])
        #expect(!composer.isDirty)

        // The next save goes over the same draft.
        app.composerChanged(composer)
        #expect(await eventually { clock.sleeping == 1 })
        clock.advance(by: .milliseconds(2500))
        #expect(await eventually { engine.calls.contains("saveDraft g1 d1") })
    }

    @Test func attachmentsMakeTheDraftWaitLonger() async {
        let (app, engine, clock) = await started()
        let composer = Composer(kind: .new, from: "g1")
        app.attach([.init(name: "a.pdf", mime: "application/pdf", bytes: Data(count: 10))], to: composer)
        #expect(await eventually { clock.sleeping == 1 })
        clock.advance(by: .milliseconds(2500))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(!engine.calls.contains { $0.hasPrefix("saveDraft") })
        clock.advance(by: .seconds(8))
        #expect(await eventually { engine.calls.contains("saveDraft g1 new") })
    }

    @Test func attachmentsStopAt25MB() async {
        let (app, _, _) = await started()
        let composer = Composer(kind: .new, from: "g1")
        app.attach([.init(name: "big.mov", mime: "video/quicktime", bytes: Data(count: 20 * 1024 * 1024))], to: composer)
        app.attach([.init(name: "more.mov", mime: "video/quicktime", bytes: Data(count: 6 * 1024 * 1024))], to: composer)
        #expect(composer.files.map(\.name) == ["big.mov"])
        #expect(composer.notice == "Attachments can be 25 MB in total.")
    }

    @Test func closingSavesWhatChangedAndDiscardingDeletesTheDraft() async {
        let (app, engine, _) = await started()
        let composer = Composer(kind: .new, from: "g1")
        composer.subject = "Plans"
        app.composerChanged(composer)
        app.presentedComposer = composer
        app.presentedComposer = nil
        #expect(app.composer == nil)
        #expect(await eventually { composer.draftID == "d1" })

        app.discard(composer)
        #expect(await eventually { engine.calls.contains("deleteDraft g1 d1") })
    }

    @Test func anEmptyComposerClosesWithoutADraft() async {
        let (app, engine, _) = await started()
        let composer = Composer(kind: .new, from: "g1")
        app.close(composer)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(!engine.calls.contains { $0.hasPrefix("saveDraft") })
    }

    @Test func changingFromMovesTheDraftOutOfTheOldAccount() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, Fixture.imap])
        engine.state.withLock {
            $0.signatures["g1"] = [SignatureInfo(id: "s-g", accountId: "g1", name: "Work", html: "<div>G</div>", isDefault: true)]
            $0.signatures["i1"] = [SignatureInfo(id: "s-i", accountId: "i1", name: "Home", html: "<div>I</div>", isDefault: true)]
        }
        let app = Fixture.app(engine)
        app.clock = TestClock().clock
        await app.start()
        await app.compose()
        let composer = try! #require(app.composer)
        #expect(composer.from == "g1")
        #expect(composer.signature?.id == "s-g")
        composer.draftID = "d9"

        await app.setFrom("i1", for: composer)
        #expect(composer.from == "i1")
        #expect(composer.signature?.id == "s-i")
        #expect(composer.draftID == nil)
        #expect(app.accountID == "g1")
        #expect(await eventually { engine.calls.contains("deleteDraft g1 d9") })
    }

    @Test func aReplyFromAnotherAccountGoesWithoutItsThreadAndGetsItBackHome() async {
        let engine = FakeEngine(accounts: [Fixture.gmail, Fixture.imap])
        let app = Fixture.app(engine)
        app.clock = TestClock().clock
        await app.start()
        let composer = Composer(kind: .reply, from: "g1")
        composer.reply = ReplyRef(threadId: "t1", messageId: "<m1@x>")
        app.present(composer)

        await app.setFrom("i1", for: composer)
        #expect(composer.reply == ReplyRef(threadId: "", messageId: "<m1@x>"))
        #expect(composer.outgoing.reply?.threadId == "")

        await app.setFrom("g1", for: composer)
        #expect(composer.reply == ReplyRef(threadId: "t1", messageId: "<m1@x>"))

        // A new message has no reply to change.
        let new = Composer(kind: .new, from: "g1")
        app.present(new)
        await app.setFrom("i1", for: new)
        #expect(new.reply == nil)
    }

    // MARK: Opening

    @Test func anAnswerStartsWithWhatTheEngineSays() async {
        let (app, engine, _) = await started()
        engine.state.withLock {
            $0.start = DraftStart(
                subject: "Re: Q4", to: ["mira@northwind.studio"], cc: [], bcc: [], quoted: "On …, Mira wrote:", kept: [],
                reply: ReplyRef(threadId: "t1", messageId: "<m1@x>"),
                signature: SignatureInfo(id: "s1", accountId: "g1", name: "Work", html: "<div>L</div>", isDefault: true)
            )
        }
        await app.startAnswer(.replyAll, to: MailThread.ID(account: "g1", thread: "t1"))
        let composer = try! #require(app.composer)
        #expect(engine.calls.contains("startAnswer t1 replyAll"))
        #expect(composer.kind == .replyAll)
        #expect(composer.from == "g1")
        #expect(composer.to == ["mira@northwind.studio"])
        #expect(composer.subject == "Re: Q4")
        #expect(composer.reply?.messageId == "<m1@x>")
        #expect(composer.signature?.id == "s1")
    }

    @Test func anAnswerThatFailsSaysSoAndOpensNothing() async {
        let (app, engine, _) = await started()
        engine.fail("startAnswer", with: .Failed(message: "The server said no."))
        await app.startAnswer(.reply, to: MailThread.ID(account: "g1", thread: "t1"))
        #expect(app.composer == nil)
        #expect(app.alert == .failed("The server said no."))
    }

    @Test func aDraftFromDraftsReopens() async {
        let (app, engine, _) = await started()
        engine.state.withLock {
            $0.draft = DraftMessage(id: "d5", to: "a@b.co", cc: "", bcc: "", subject: "Hi", body: "x", quoted: nil, html: "<div>x</div>", attachments: [], reply: nil)
        }
        await app.openDraft(thread: MailThread.ID(account: "g1", thread: "t5"))
        #expect(app.composer?.draftID == "d5")
        #expect(app.composer?.kind == .draft)
    }

    @Test func aMailtoLinkOpensANewMessage() async {
        let (app, _, _) = await started()
        #expect(app.openMailto(URL(string: "mailto:ana@example.com?cc=ben@example.com&subject=Lunch&body=Friday%3F")!))
        let composer = try! #require(app.composer)
        #expect(composer.to == ["ana@example.com"])
        #expect(composer.cc == ["ben@example.com"])
        #expect(composer.subject == "Lunch")
        #expect(composer.text == "Friday?")
        #expect(!app.openMailto(URL(string: "https://example.com")!))
    }

    @Test func unsubscribingByMailPreparesTheListsMessage() async {
        let (app, _, _) = await started()
        await app.startUnsubscribe(to: "leave@list.example", subject: "unsubscribe", body: "", account: "g1")
        let composer = try! #require(app.composer)
        #expect(composer.to == ["leave@list.example"])
        #expect(composer.subject == "unsubscribe")
        #expect(composer.signature == nil)
        #expect(composer.outgoing.body.isEmpty)

        // Never into a message being written.
        await app.startUnsubscribe(to: "other@list.example", subject: "x", body: "", account: "g1")
        #expect(app.composer === composer)
        #expect(app.toast?.text == "Finish or close what you are writing, then tap Unsubscribe again.")
    }

    // MARK: Helpers

    private func started() async -> (AppModel, FakeEngine, TestClock) {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        let app = Fixture.app(engine)
        let clock = TestClock()
        app.clock = clock.clock
        await app.start()
        return (app, engine, clock)
    }
}
