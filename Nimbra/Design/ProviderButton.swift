import SwiftUI

/// The kit's Button (Kind=Secondary) with a provider's logo: Continue with
/// Google or Microsoft.
struct ProviderButton<Logo: View>: View {
    let title: LocalizedStringKey
    let action: () -> Void
    @ViewBuilder let logo: Logo

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                logo
                Text(title)
                    .nimbraText(.headline)
            }
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.surfaceRaised, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.borderStrong))
        }
        .buttonStyle(.plain)
    }
}
