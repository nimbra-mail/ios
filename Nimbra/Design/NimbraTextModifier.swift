import SwiftUI

extension View {
    /// Sets a Figma text style: its font (scaling with Dynamic Type), its
    /// letter spacing, and its line height as spacing between lines.
    func nimbraText(_ style: NimbraTextStyle) -> some View {
        modifier(NimbraTextModifier(style: style))
    }
}

extension EnvironmentValues {
    /// How much larger the text of an email is drawn than its style says (Settings ›
    /// Appearance › Mail text size), on top of Dynamic Type. Set on a message's body only:
    /// the rest of the app keeps 1.
    @Entry var mailTextScale: CGFloat = 1
}

private struct NimbraTextModifier: ViewModifier {
    let style: NimbraTextStyle
    @ScaledMetric private var scale: CGFloat = 1
    @Environment(\.mailTextScale) private var mailScale

    func body(content: Content) -> some View {
        // A font's natural line is about 1.25 of its size: the rest of
        // Figma's line height goes between lines.
        let extra = max(0, style.lineHeight - style.size * 1.25) * scale * mailScale
        content
            .font(mailScale == 1 ? style.font : style.font(scaledBy: mailScale))
            .tracking(style.tracking * mailScale)
            .lineSpacing(extra)
    }
}
