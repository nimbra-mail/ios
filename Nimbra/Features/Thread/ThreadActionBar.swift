import SwiftUI

/// Done, Snooze, Reply and Forward in one Liquid Glass capsule.
struct ThreadActionBar: View {
    let done: () -> Void
    let snooze: () -> Void
    let reply: () -> Void
    let forward: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            action("Done", .done, done)
            action("Snooze", .clock, snooze)
            action("Reply", .reply, reply)
            action("Forward", .forward, forward)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func action(_ title: LocalizedStringKey, _ icon: NimbraIcon, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(spacing: 4) {
                Icon(icon, size: 18)
                Text(title).nimbraText(.subheadMedium)
            }
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
