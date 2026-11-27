import SwiftUI

/// 16 · Notifications · Ask: shown at the first new mail, before the system's prompt.
/// The bell in the brand gradient, "Know when mail arrives", what the notifications
/// are, Turn on notifications and Not now.
struct NotificationAskSheet: View {
    @Environment(AppModel.self) private var app
    /// The sheet is as tall as what it says, at any text size.
    @State private var height: CGFloat = 423

    var body: some View {
        VStack(spacing: 14) {
            Icon(.bell, size: 28)
                .foregroundStyle(Color.onAccent)
                .frame(width: 64, height: 64)
                .background(.brandButton, in: .circle)
                .accessibilityHidden(true)
                .padding(.bottom, 2)
            Text("Know when \(Text("mail arrives").font(NimbraTextStyle.titleItalic.font))")
                .nimbraText(.title)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("One quiet notification for each new conversation, with the sender and subject. Mark it done or read right from there. Blocked senders never notify.")
                .nimbraText(.subhead)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
            PrimaryButton("Turn on notifications") {
                Task { await app.turnOnNotifications() }
            }
            Button {
                app.notNowNotifications()
            } label: {
                Text("Not now")
                    .nimbraText(.bodyMedium)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 12)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surfaceRaised)
    }
}

#Preview {
    Color.bgList.sheet(isPresented: .constant(true)) {
        NotificationAskSheet()
    }
    .environment(AppModel.sample())
}
