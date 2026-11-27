// Stub: delete on merge with feat/compose
//
// Compose's toast and composer hooks, with its exact signatures, so Mailboxes builds on its
// own branch. feat/compose ships the real ones: `Model/Toast.swift`, `AppModel.toast` drawn
// by MainTabView, `show(_:undo:)`, `compose()` and `openDraft(thread:)`.
import Foundation

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

    func compose() async {}

    func openDraft(thread: MailThread.ID) async {}
}
