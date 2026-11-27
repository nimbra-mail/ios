import SwiftUI

/// The kit's Account Row: a photo (Avatar, 28), a name in Body and an address in Footnote,
/// with a check when it is the one picked. Address suggestions, the From picker.
struct PersonRow: View {
    let person: Person
    /// The name as shown: a suggestion makes what was typed Medium.
    let title: Text
    let subtitle: String
    var isChecked = false
    var isHighlighted = false
    var divider = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(person: person, size: 28)
            VStack(alignment: .leading, spacing: 0) {
                title
                    .nimbraText(.body)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(verbatim: subtitle)
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isChecked {
                Icon(.check, size: 20)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 10)
        .background(isHighlighted ? Color.surfaceSelected : .clear)
        .overlay(alignment: .top) {
            if divider { Divider().overlay(Color.borderSubtle) }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

extension Text {
    /// A name with the part that matches what was typed in Medium (13 · Suggestions).
    static func matching(_ name: String, typed: String) -> Text {
        let typed = typed.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty, let range = name.range(of: typed, options: [.caseInsensitive, .anchored])
                ?? name.range(of: " " + typed, options: .caseInsensitive).map({ name.index(after: $0.lowerBound)..<$0.upperBound })
        else { return Text(verbatim: name) }
        var styled = AttributedString(name)
        if let match = Range(range, in: styled) {
            styled[match].font = NimbraTextStyle.bodyMedium.font
        }
        return Text(styled)
    }
}
