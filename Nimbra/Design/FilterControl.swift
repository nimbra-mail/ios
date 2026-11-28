import SwiftUI

/// The kit's Filter: a small capsule choice at the head of a list (All, or Unread with its
/// count), in the Chips' look: the selected one on surface/selected with an accent edge and
/// an accent label, the others in text/secondary with their count in text/tertiary.
struct FilterControl<Value: Hashable & Identifiable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> Text
    /// A count after an option's label, when it has one.
    var count: (Value) -> Int? = { _ in nil }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                segment(option)
            }
        }
        .padding(3)
        .background(Color.surfaceHover, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.borderSubtle))
        .fixedSize()
    }

    private func segment(_ option: Value) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
        } label: {
            HStack(spacing: 6) {
                label(option)
                    .nimbraText(.subheadMedium)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.textSecondary)
                if let count = count(option), count > 0 {
                    Text(count, format: .number)
                        .nimbraText(.caption)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.textTertiary)
                }
            }
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: 32)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.surfaceSelected)
                        .strokeBorder(Color.accentColor)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.smooth(duration: 0.2), value: isSelected)
    }
}
