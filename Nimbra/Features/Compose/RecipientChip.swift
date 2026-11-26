import SwiftUI

/// An address in To, with ✕ to take it out.
struct RecipientChip: View {
    let address: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: address)
                .nimbraText(.subhead)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Button(action: remove) {
                Icon(.x, size: 12)
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Remove \(address)"))
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(Color.surfaceSelected, in: .capsule)
    }
}
