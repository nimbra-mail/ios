import SwiftUI

/// A composer row: its label, then what is in it, with a line above.
struct ComposeField<Content: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .nimbraText(.subhead)
                .foregroundStyle(Color.textTertiary)
                .frame(width: 62, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 48)
        .overlay(alignment: .top) { Divider().overlay(Color.borderSubtle) }
    }
}
