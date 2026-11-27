import Foundation

/// What the toast over the tab bar says (the kit's iOS/Toast): an icon, a sentence, and
/// at most one action.
nonisolated struct Toast: Identifiable, Equatable, Sendable {
    nonisolated enum Action: Equatable, Sendable {
        /// Takes a held message back (`AppModel.undoSend`).
        case undoSend(UUID)
        /// Runs the undo given to `AppModel.show(_:undo:)` (Done, a block, a snooze).
        case undo(UUID)
    }

    let id = UUID()
    var icon: NimbraIcon
    var text: String
    var action: Action?
    /// How long it stays; nil keeps it until something replaces it.
    var duration: Duration?

    init(icon: NimbraIcon, text: String, action: Action? = nil, duration: Duration? = .seconds(4)) {
        self.icon = icon
        self.text = text
        self.action = action
        self.duration = duration
    }

    /// What a notice that says what happened to someone's mail stays for.
    static let telling = Duration.seconds(8)
}
