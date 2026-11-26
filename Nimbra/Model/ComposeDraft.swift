import Foundation

/// A message being written: new, a reply or a forward.
nonisolated struct ComposeDraft: Identifiable, Hashable {
    let id = UUID()
    var to: [String] = []
    var subject = ""
    var body = ""

    /// To the latest sender, "Re:" before the subject (once).
    static func reply(to thread: MailThread) -> ComposeDraft {
        let subject = thread.subject.hasPrefix("Re: ") ? thread.subject : "Re: \(thread.subject)"
        return ComposeDraft(to: thread.sender.map { [$0.email] } ?? [], subject: subject)
    }

    /// To no one yet, "Fwd:" before the subject (once).
    static func forward(_ thread: MailThread) -> ComposeDraft {
        let subject = thread.subject.hasPrefix("Fwd: ") ? thread.subject : "Fwd: \(thread.subject)"
        return ComposeDraft(subject: subject)
    }
}
