import NimbraCore
import SwiftUI

/// An empty mailbox, in the Mac's words: what will show up here, or how to put something
/// here (Snoozed, Reminders).
struct EmptyMailboxView: View {
    let mailbox: Mailbox
    let name: String

    var body: some View {
        VStack(spacing: 6) {
            Text("Nothing in \(name)")
                .nimbraText(.headline)
                .foregroundStyle(Color.textPrimary)
            hint
                .nimbraText(.subhead)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var hint: Text {
        switch mailbox {
        case .snoozed: Text("Snooze a thread to put it away until later.")
        case .reminders: Text("Snooze a thread and pick “Remind me if no reply” to be told when nobody answers.")
        default: Text("Threads will show up here.")
        }
    }
}
