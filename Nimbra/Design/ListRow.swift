import SwiftUI

/// The kit's List Row: a grouped list row (Settings, pickers). An optional 20 pt icon in the
/// accent, the title in Body, then what is on the right (a value, a switch, a check or a
/// chevron). A hairline above every row but the first of its group.
struct ListRow<Trailing: View>: View {
    let icon: NimbraIcon?
    let title: Text
    let titleColor: Color
    let iconColor: Color
    let divider: Bool
    let trailing: Trailing

    init(
        _ title: Text, icon: NimbraIcon? = nil, titleColor: Color = .textPrimary, iconColor: Color = .accentColor,
        divider: Bool = true, @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.titleColor = titleColor
        self.iconColor = iconColor
        self.divider = divider
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Icon(icon).foregroundStyle(iconColor)
            }
            title
                .nimbraText(.body)
                .foregroundStyle(titleColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(minHeight: 50)
        .contentShape(.rect)
        .overlay(alignment: .top) {
            if divider { Divider().overlay(Color.borderSubtle) }
        }
    }
}

/// A List Row's value on the right, in Subhead.
struct ListRowValue: View {
    let text: Text

    init(_ text: Text) { self.text = text }

    var body: some View {
        text
            .nimbraText(.subhead)
            .foregroundStyle(Color.textTertiary)
            .lineLimit(1)
    }
}

/// The chevron that ends a List Row that opens a screen.
struct ListRowChevron: View {
    var body: some View {
        Icon(.next, size: 16).foregroundStyle(Color.textFaint)
    }
}
