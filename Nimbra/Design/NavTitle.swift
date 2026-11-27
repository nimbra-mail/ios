import SwiftUI

/// The kit's Nav Title: a screen's title in Headline in the top bar, with an optional
/// Overline under it (the date, the account, "If nobody replies").
struct NavTitle: View {
    let title: Text
    var subtitle: Text?

    var body: some View {
        VStack(spacing: 0) {
            title
                .nimbraText(.headline)
                .foregroundStyle(Color.textPrimary)
            if let subtitle {
                subtitle
                    .textCase(.uppercase)
                    .nimbraText(.overline)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
