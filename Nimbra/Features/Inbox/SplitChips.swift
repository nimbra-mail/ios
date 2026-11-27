import SwiftUI

/// The split inbox's chips, running past the screen's edge: Inbox (all of it) first, then
/// Gmail's categories, each with its unread count (02 · Inbox).
struct SplitChips: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(nil)
                ForEach(SplitCategory.allCases) { category in
                    chip(category)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    /// A category's chip, or (nil) the whole Inbox's.
    private func chip(_ category: SplitCategory?) -> some View {
        let isSelected = category == app.split
        let unread = app.unreadCount(category)
        return Button {
            Task { await app.selectSplit(category) }
        } label: {
            HStack(spacing: 6) {
                Text(category?.title ?? "Inbox")
                    .nimbraText(.subheadMedium)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                if unread > 0 {
                    Text(unread, format: .number)
                        .nimbraText(.caption)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.surfaceSelected : Color.surfaceHover, in: .capsule)
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.accentColor.opacity(0.45) : Color.borderSubtle)
            )
            .animation(.smooth, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
