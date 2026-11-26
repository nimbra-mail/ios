import SwiftUI

/// The kit's Nav Bar for a sheet, as in Compose: a glass button on the leading side (back
/// or close), the title centered in Headline, and room on the trailing side so it stays
/// centered.
struct SheetNavBar: View {
    /// What the leading button does.
    enum Leading {
        case back, close

        var icon: NimbraIcon { self == .back ? .back : .x }
        var label: LocalizedStringKey { self == .back ? "Back" : "Close" }
    }

    let title: Text
    let leading: Leading
    let action: () -> Void

    init(_ title: LocalizedStringKey, leading: Leading, action: @escaping () -> Void) {
        self.title = Text(title)
        self.leading = leading
        self.action = action
    }

    var body: some View {
        HStack(spacing: 8) {
            GlassIconButton(icon: leading.icon, label: leading.label, action: action)
            title
                .nimbraText(.headline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            Color.clear.frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
