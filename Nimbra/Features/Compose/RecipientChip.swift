import SwiftUI

/// An address in To, Cc or Bcc, with ✕ to take it out.
struct RecipientChip: View {
    let address: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: address)
                .nimbraText(.subhead)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Button(action: remove) {
                Icon(.x, size: 12)
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.vertical, -2)
            .accessibilityLabel(Text("Remove \(address)"))
        }
        .padding(.leading, 10)
        .padding(.trailing, 2)
        .padding(.vertical, 4)
        .background(Color.surfaceSelected, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("Remove")) { remove() }
    }
}
