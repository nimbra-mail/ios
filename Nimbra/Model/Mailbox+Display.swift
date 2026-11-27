import Foundation
import NimbraCore

/// How a mailbox reads in Mailboxes and at the top of its list: its name and kit icon, as
/// the Mac's sidebar names and draws them (`app.rs`, `sidebar.rs`).
nonisolated extension Mailbox {
    /// The name of a mailbox every account has; nil for a label (its name is its own).
    var title: LocalizedStringResource? {
        switch self {
        case .inbox: "Inbox"
        case .split(let category): SplitCategory(category).title
        case .starred: "Starred"
        case .important: "Important"
        case .snoozed: "Snoozed"
        case .reminders: "Reminders"
        case .drafts: "Drafts"
        case .sent: "Sent"
        case .done: "Done"
        case .allMail: "All Mail"
        case .spam: "Spam"
        case .trash: "Trash"
        case .label: nil
        }
    }

    var icon: NimbraIcon {
        switch self {
        case .inbox: .inbox
        case .split(let category): SplitCategory(category).icon
        case .starred: .star
        case .important: .activity
        case .snoozed: .clock
        case .reminders: .bell
        case .drafts: .draft
        case .sent: .send
        case .done: .done
        case .allMail: .archive
        case .spam: .ban
        case .trash: .trash
        case .label: .tag
        }
    }

    /// The inbox or a Split Inbox category: Done takes a thread out of it, and Move to a
    /// label moves it (rather than adding the label).
    var isInboxLike: Bool {
        switch self {
        case .inbox, .split: true
        default: false
        }
    }

    /// What takes a thread out of this mailbox and back to the inbox, where the Mac's Done
    /// does that instead of archiving: Done, Spam, Trash.
    var restoringAction: ThreadAction? {
        switch self {
        case .done: .moveToInbox
        case .spam: .notSpam
        case .trash: .untrash
        default: nil
        }
    }

    /// The label id whose counts the row shows, and whether it shows the unread threads
    /// or all of them (Drafts), as the Mac does. Nil: no count.
    var countedLabel: (id: String, unread: Bool)? {
        switch self {
        case .inbox: ("INBOX", true)
        case .split(let category): (SplitCategory(category).labelID, true)
        case .important: ("IMPORTANT", true)
        case .drafts: ("DRAFT", false)
        case .label(let id): (id, true)
        default: nil
        }
    }
}

nonisolated extension SplitCategory {
    /// The app's category for the engine's.
    init(_ category: NimbraCore.SplitCategory) {
        self = switch category {
        case .primary: .primary
        case .updates: .updates
        case .promotions: .promotions
        case .social: .social
        }
    }
}
