import SwiftUI

/// A screen of Settings: its title in the nav bar (Headline), and its groups scrolling on
/// the sheet.
struct SettingsScreen<Content: View>: View {
    let title: Text
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 8) { content }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.surfaceRaised)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                title
                    .nimbraText(.headline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }
}
