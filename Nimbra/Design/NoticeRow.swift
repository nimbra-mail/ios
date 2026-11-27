import SwiftUI

/// The kit's List Row, for a notice in a grouped card: a 20pt icon and Subhead text that
/// wraps. A hairline above every row but the first.
struct NoticeRow: View {
    let icon: NimbraIcon
    let iconColor: Color
    let text: Text
    var textColor = Color.textPrimary
    var divider = false
    /// Spins the icon (the loader).
    var spins = false

    @State private var angle = Angle.zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: spins ? .center : .top, spacing: 12) {
            Icon(icon)
                .foregroundStyle(iconColor)
                .rotationEffect(angle)
                .onAppear {
                    guard spins, !reduceMotion else { return }
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { angle = .degrees(360) }
                }
            text
                .nimbraText(.subhead)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(minHeight: 50)
        .overlay(alignment: .top) {
            if divider { Divider().overlay(Color.borderSubtle) }
        }
        .accessibilityElement(children: .combine)
    }
}
