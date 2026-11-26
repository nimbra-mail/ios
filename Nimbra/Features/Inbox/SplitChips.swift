import SwiftUI

/// The split inbox's categories as chips, running past the screen's edge.
struct SplitChips: View {
    @Binding var selection: SplitCategory
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(SplitCategory.allCases) { category in
                    chip(category)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ category: SplitCategory) -> some View {
        let isSelected = category == selection
        let unread = app.unreadCount(category)
        return Button {
            withAnimation(.smooth) { selection = category }
        } label: {
            HStack(spacing: 6) {
                Text(category.title)
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
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
