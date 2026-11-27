import Foundation

/// The Labels sheet for a thread (15 · Labels): pick its labels, or move it to one.
nonisolated struct LabelRequest: Identifiable, Hashable, Sendable {
    nonisolated enum Mode: Hashable, Sendable {
        /// Labels added and taken off, each with a tap.
        case label
        /// Move to: the label added and, from an inbox, out of it.
        case move
    }

    let thread: MailThread.ID
    let mode: Mode

    var id: Self { self }
}
