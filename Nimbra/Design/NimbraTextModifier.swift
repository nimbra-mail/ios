import SwiftUI

extension View {
    /// Sets a Figma text style: its font (scaling with Dynamic Type), its
    /// letter spacing, and its line height as spacing between lines.
    func nimbraText(_ style: NimbraTextStyle) -> some View {
        modifier(NimbraTextModifier(style: style))
    }
}

private struct NimbraTextModifier: ViewModifier {
    let style: NimbraTextStyle
    @ScaledMetric private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        // A font's natural line is about 1.25 of its size: the rest of
        // Figma's line height goes between lines.
        let extra = max(0, style.lineHeight - style.size * 1.25) * scale
        content
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(extra)
    }
}
