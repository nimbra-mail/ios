import SwiftUI

/// The kit's Fact Row: a settings row that states a fact, with its icon in the accent, a
/// title in Body and a line or two of detail in Footnote. Not tappable (Settings › Privacy).
/// A hairline above every row but the first of its group.
struct FactRow: View {
    let icon: NimbraIcon
    let title: Text
    let detail: Text
    var divider = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Icon(icon)
                .foregroundStyle(Color.accentColor)
                // On the title's first line (Body, 24 pt).
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .nimbraText(.body)
                    .foregroundStyle(Color.textPrimary)
                detail
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .overlay(alignment: .top) {
            if divider { Divider().overlay(Color.borderSubtle) }
        }
        .accessibilityElement(children: .combine)
    }
}
