import SwiftUI

/// Today's date as an overline over a screen's serif title.
struct InboxHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                .nimbraText(.overline)
                .foregroundStyle(Color.textTertiary)
            Text(title)
                .nimbraText(.largeTitle)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
