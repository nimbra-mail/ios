import SwiftUI

/// The kit's Nav Title: a screen's title in Headline in the top bar, with an optional
/// Overline under it (the date, the account, "If nobody replies").
struct NavTitle: View {
    let title: Text
    var subtitle: Text?
    /// The Overline's color: tertiary, or amber for the Inbox's Offline state (14 · Offline).
    var subtitleColor = Color.textTertiary

    var body: some View {
        VStack(spacing: 0) {
            title
                .nimbraText(.headline)
                .foregroundStyle(Color.textPrimary)
            if let subtitle {
                subtitle
                    .textCase(.uppercase)
                    .nimbraText(.overline)
                    .foregroundStyle(subtitleColor)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
