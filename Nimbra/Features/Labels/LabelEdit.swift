import Foundation

/// A change to an account's labels waiting on the person: a name to type, or a delete to
/// confirm.
nonisolated enum LabelEdit: Identifiable, Hashable, Sendable {
    /// A new label, put on `thread` when there is one.
    case new(account: Account.ID, thread: MailThread.ID?)
    case rename(MailLabel, account: Account.ID)
    case delete(MailLabel, account: Account.ID)

    var id: Self { self }
}
