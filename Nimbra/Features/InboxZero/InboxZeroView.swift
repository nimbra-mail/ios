import SwiftUI

/// 07 · Inbox zero: the serif headline, the aurora (the Figma frame's own artwork: its
/// glows, stars and horizon) rising from the bottom, and the day's line over it. Laid out
/// on the whole screen as in the 402 × 874 frame, and arriving as on the Mac: the glow
/// comes up, then the words settle into place (still with Reduce Motion).
struct InboxZeroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Color.bgList
                Image(.aurora)
                    .resizable()
                    .frame(width: Self.aurora.width, height: Self.aurora.height)
                    // Its top 475.6 pt above the bottom, 10 pt left of center, as in the frame.
                    .position(x: width / 2 - 10, y: height - 475.6 + Self.aurora.height / 2)
                    .opacity(arrived ? 1 : 0)
                    .accessibilityHidden(true)
                Text("Inbox \(Text("zero.").font(NimbraTextStyle.displayItalic.font))")
                    .nimbraText(.display)
                    .foregroundStyle(Color.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                    .accessibilityAddTraits(.isHeader)
                    .position(x: width / 2, y: height * 295 / 874)
                    .offset(y: arrived || reduceMotion ? 0 : 8)
                    .opacity(arrived ? 1 : 0)
                Text("Spend the evening with good people.")
                    .nimbraText(.quote)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .position(x: width / 2, y: height - 201)
                    .offset(y: arrived || reduceMotion ? 0 : 8)
                    .opacity(arrived ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.3 : 1.2)) { arrived = true }
        }
    }

    /// The aurora's size in points (the frame's, with its glow's reach).
    private static let aurora = CGSize(width: 1066.4, height: 644.8)
}

#Preview {
    InboxZeroView()
}
