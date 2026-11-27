import SwiftUI

/// A composer row: its label in Subhead, then what is in it, with a line above.
struct ComposeField<Content: View>: View {
    let label: LocalizedStringKey
    var spacing: CGFloat = 12
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            Text(label)
                .nimbraText(.subhead)
                .foregroundStyle(Color.textTertiary)
                .frame(width: 62, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .frame(minHeight: 46)
        .overlay(alignment: .top) { Divider().overlay(Color.borderSubtle) }
    }
}
