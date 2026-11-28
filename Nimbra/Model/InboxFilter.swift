import Foundation

/// What the inbox lists (02 · Inbox, the Filter at the head of the list): every thread, or
/// only the unread ones.
nonisolated enum InboxFilter: Hashable, CaseIterable, Identifiable, Sendable {
    case all, unread

    var id: Self { self }

    var label: LocalizedStringResource {
        switch self {
        case .all: "All"
        case .unread: "Unread"
        }
    }

    /// The threads this filter lets through, in their order.
    func apply(_ threads: [MailThread]) -> [MailThread] {
        switch self {
        case .all: threads
        case .unread: threads.filter(\.isUnread)
        }
    }
}
