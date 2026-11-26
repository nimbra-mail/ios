import SwiftUI

/// 01 · Welcome: connect the first account.
struct WelcomeView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(.appIconPreview)
                    .resizable()
                    .frame(width: 112, height: 112)
                    .accessibilityHidden(true)
                Text("Connect your \(Text("inbox").font(NimbraTextStyle.largeTitleItalic.font))")
                    .nimbraText(.largeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Nimbra signs in with your provider. Your mail stays on this iPhone, encrypted.")
                    .nimbraText(.subhead)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            Spacer()
            VStack(spacing: 12) {
                ProviderButton(title: "Continue with Google", action: app.signIn) {
                    Image(.logoGoogle).resizable().frame(width: 20, height: 20)
                }
                ProviderButton(title: "Continue with Microsoft", action: app.signIn) {
                    MicrosoftLogo()
                }
                Button("Use another address", action: app.signIn)
                    .nimbraText(.bodyMedium)
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 2)
                Text("Private by default. No ads, no tracking.")
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Color.bgList
                // A soft sky behind the icon, like the desktop's first screen.
                RadialGradient(
                    colors: [Color.accentColor.opacity(0.34), Color.accentRose.opacity(0.08), .clear],
                    center: .init(x: 0.5, y: 0.32), startRadius: 0, endRadius: 260
                )
                .blur(radius: 40)
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    WelcomeView().environment(AppModel())
}
