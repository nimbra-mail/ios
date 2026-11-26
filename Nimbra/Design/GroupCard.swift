import SwiftUI

/// Grouped rows in a rounded card (Snooze, Mailboxes).
struct GroupCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color.surfaceHover, in: .rect(cornerRadius: 18))
            .clipShape(.rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.borderSubtle))
    }
}

/// A row in a `GroupCard`: an icon, a title, what is on the right, and a
/// line above every row but the first.
struct GroupRow<Trailing: View>: View {
    let icon: NimbraIcon
    let iconColor: Color
    let title: Text
    let divider: Bool
    let trailing: Trailing
    /// Without one, the row is not a button.
    let action: (() -> Void)?

    init(icon: NimbraIcon, iconColor: Color, title: Text, divider: Bool, @ViewBuilder trailing: () -> Trailing, action: (() -> Void)? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.divider = divider
        self.trailing = trailing()
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { row }
                    .buttonStyle(.plain)
            } else {
                row.accessibilityElement(children: .combine)
            }
        }
        .overlay(alignment: .top) {
            if divider { Divider().overlay(Color.borderSubtle) }
        }
    }

    private var row: some View {
        HStack(spacing: 12) {
            Icon(icon).foregroundStyle(iconColor)
            title
                .nimbraText(.body)
                .foregroundStyle(Color.textPrimary)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .contentShape(.rect)
    }
}
