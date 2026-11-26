import SwiftUI

/// The kit's Glass Button: a 44pt circle of Liquid Glass with one icon.
struct GlassIconButton: View {
    let icon: NimbraIcon
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Icon(icon, size: 20)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text(label))
    }
}
