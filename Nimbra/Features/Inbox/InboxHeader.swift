import SwiftUI

/// Today's date as an overline over a screen's serif title.
struct InboxHeader: View {
    let title: LocalizedStringKey
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // MARK: Sending: offline, the overline says so and how much waits (14 · Offline).
            if let subtitle = app.connectionSubtitle {
                Text(verbatim: subtitle)
                    .nimbraText(.overline)
                    .foregroundStyle(Color.accentAmber)
            } else {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .nimbraText(.overline)
                    .foregroundStyle(Color.textTertiary)
            }
            Text(title)
                .nimbraText(.largeTitle)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
