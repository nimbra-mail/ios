import Foundation

/// The tab bar's tabs.
nonisolated enum AppTab: CaseIterable, Identifiable {
    case inbox, snoozed, mailboxes

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .inbox: "Inbox"
        case .snoozed: "Snoozed"
        case .mailboxes: "Mailboxes"
        }
    }

    var icon: NimbraIcon {
        switch self {
        case .inbox: .inbox
        case .snoozed: .clock
        case .mailboxes: .sidebar
        }
    }
}
