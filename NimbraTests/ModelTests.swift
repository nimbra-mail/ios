import Foundation
import Testing
@testable import Nimbra

struct ModelTests {
    @Test(arguments: [
        ("Mira Kovač", "MK"),
        ("Stripe", "S"),
        ("Ana María Petrović", "AP"),
    ])
    func initials(name: String, expected: String) {
        #expect(Person(name: name, email: "a@b.c").initials == expected)
    }

    @Test func initialsFallBackToTheAddress() {
        #expect(Person(name: "", email: "zoe@example.com").initials == "Z")
    }

    @Test func accountsAreNamedAfterTheirAddress() {
        let account = Account(id: "a", email: "luan.gjokaj@riangle.com", kind: .imap)
        #expect(account.name == "riangle.com")
        #expect(account.person.name == "Luan Gjokaj")
        #expect(account.person.initials == "LG")
    }

    @Test func rowsComeFromTheEngine() {
        let row = Fixture.row("t1", unread: true, at: 1_800_000_000)
        let thread = MailThread(row: row, account: "a1")
        #expect(thread.id == MailThread.ID(account: "a1", thread: "t1"))
        #expect(thread.date == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(thread.isUnread)
        #expect(thread.participants.map(\.name) == ["Ben"])
    }

    @Test func toneIsStableForAName() {
        #expect(Tone.for("Mira Kovač") == Tone.for("Mira Kovač"))
    }

    @Test func replyAndForwardPrefixOnce() {
        let thread = SampleData.threads()[0]
        #expect(ComposeDraft.reply(to: thread).subject == "Re: Q4 launch plan, final review")
        #expect(ComposeDraft.reply(to: thread).to == ["mira@northwind.studio"])
        var answered = thread
        answered.subject = "Re: Plans"
        answered.messages = []
        answered.sender = Person(name: "Ben", email: "")
        #expect(ComposeDraft.reply(to: answered).to.isEmpty)
        #expect(ComposeDraft.reply(to: answered).subject == "Re: Plans")
        #expect(ComposeDraft.forward(thread).subject == "Fwd: Q4 launch plan, final review")
    }

    // The snooze times are the engine's now (`snooze_times`, tested in core); the sheet's
    // reading of them is in BackgroundTests.
}
