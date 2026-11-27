import SwiftUI

/// The kit's Toast, floating over the tab bar: an icon, a sentence in Subhead Medium and
/// at most one action, a 44pt target in the accent (Undo).
struct ToastView: View {
    let toast: Toast
    let act: (Toast.Action) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Icon(toast.icon, size: 18)
                .foregroundStyle(toast.icon == .wifiOff ? Color.accentAmber : Color.textSecondary)
            Text(verbatim: toast.text)
                .nimbraText(.subheadMedium)
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 12)
            if let action = toast.action {
                Button {
                    act(action)
                } label: {
                    Text(action.title)
                        .nimbraText(.subheadMedium)
                        .fixedSize()
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Color.surfaceSelected, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .layoutPriority(1)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, toast.action == nil ? 18 : 6)
        .padding(.vertical, 6)
        .frame(minHeight: 56)
        .glassEffect(.regular.tint(Color.surfaceRaised), in: .capsule)
        .overlay(Capsule().strokeBorder(Color.borderSubtle))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }
}

private extension Toast.Action {
    var title: LocalizedStringKey {
        switch self {
        case .undoSend, .undo: "Undo"
        }
    }
}
