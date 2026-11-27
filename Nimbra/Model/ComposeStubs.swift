// Stub: delete on merge with feat/compose
//
// What Reading calls of Compose, with feat/compose's exact signatures; they do nothing
// here. feat/compose brings the real ones (AppModel+ComposeHooks, Model/Toast.swift).
import Foundation
import NimbraCore

/// A short notice at the bottom ("Moved to trash" · Undo).
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
    func compose() async {}
    func startAnswer(_ answer: Answer, to thread: MailThread.ID) async {}
    func openDraft(thread: MailThread.ID) async {}
    func openMailto(_ url: URL) -> Bool { parseMailto(link: url.absoluteString) != nil }
    func startUnsubscribe(to: String, subject: String, body: String, account: Account.ID) async {}
    func show(_ toast: Toast, undo: (@MainActor () async -> Void)? = nil) {}
}
