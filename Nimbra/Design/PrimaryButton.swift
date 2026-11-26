import SwiftUI

/// The kit's Button (Kind=Primary): the brand gradient, its title in Headline on top, a
/// soft violet glow under it. Dimmed while it cannot be used.
struct PrimaryButton: View {
    let title: Text
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = Text(title)
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            title
                .nimbraText(.headline)
                .foregroundStyle(Color.onAccent)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(.brandButton, in: .rect(cornerRadius: 14))
                .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 8)
                .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
    }
}
