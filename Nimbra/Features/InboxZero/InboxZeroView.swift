import SwiftUI

/// 07 · Inbox zero: the serif headline over the aurora, and the day's line.
struct InboxZeroView: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("Inbox \(Text("zero.").font(NimbraTextStyle.displayItalic.font))")
                .nimbraText(.display)
                .foregroundStyle(Color.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text("Spend the evening with good people.")
                .nimbraText(.quote)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .background(alignment: .bottom) { Aurora() }
    }
}

/// Soft violet, rose, amber and sky light rising from the bottom, as on the
/// desktop's Inbox zero.
private struct Aurora: View {
    var body: some View {
        ZStack {
            glow(Color(red: 0.42, green: 0.30, blue: 1), 0.75, x: -110, y: 30, w: 330, h: 230)
            glow(Color(red: 1, green: 0.31, blue: 0.63), 0.6, x: 40, y: 70, w: 270, h: 190)
            glow(Color(red: 1, green: 0.66, blue: 0.30), 0.45, x: 150, y: 110, w: 230, h: 140)
            glow(Color(red: 0.25, green: 0.66, blue: 1), 0.35, x: 170, y: -20, w: 210, h: 140)
        }
        .frame(height: 300)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glow(_ color: Color, _ opacity: Double, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        Ellipse()
            .fill(color.opacity(opacity))
            .frame(width: w, height: h)
            .blur(radius: 60)
            .offset(x: x, y: y)
    }
}
