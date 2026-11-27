import Foundation

// Stub: delete on merge with feat/compose
//
// What Compose and sending provides, as agreed: the toast (with Undo), the outbox catch-up
// (all accounts: unsent pick-up, catch_up, send_due) and its soonest deadline. These do
// nothing here.

nonisolated struct Toast: Identifiable, Equatable, Sendable {
    enum Action: Equatable, Sendable {}

    let id = UUID()
    let icon: NimbraIcon
    let text: String
    let action: Action?
    let duration: Duration?

    init(icon: NimbraIcon, text: String, action: Action? = nil, duration: Duration? = .seconds(4)) {
        self.icon = icon
        self.text = text
        self.action = action
        self.duration = duration
    }
}

extension AppModel {
    func show(_ toast: Toast, undo: (@MainActor () async -> Void)? = nil) {}

    func catchUpOutbox() async {}

    func outboxDeadline() async -> Date? { nil }
}
