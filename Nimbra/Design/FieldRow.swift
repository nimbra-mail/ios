import SwiftUI

/// The kit's Field Row: a labelled text field in a grouped card. The label is 96 wide in
/// Subhead; the value is Body, its placeholder faint; an optional accessory (the eye that
/// shows a password) at the end. A hairline above every row but the first.
struct FieldRow<Field: View, Accessory: View>: View {
    let label: LocalizedStringKey
    let divider: Bool
    let field: Field
    let accessory: Accessory

    init(_ label: LocalizedStringKey, divider: Bool, @ViewBuilder field: () -> Field, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.label = label
        self.divider = divider
        self.field = field()
        self.accessory = accessory()
    }

    @ScaledMetric(relativeTo: .subheadline) private var labelWidth: CGFloat = 96

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .nimbraText(.subhead)
                .foregroundStyle(Color.textTertiary)
                .frame(width: labelWidth, alignment: .leading)
                .accessibilityHidden(true)
            field
                .nimbraText(.body)
                .foregroundStyle(Color.textPrimary)
                .tint(Color.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            accessory
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .overlay(alignment: .top) {
            if divider { Divider().overlay(Color.borderSubtle) }
        }
    }
}

extension Text {
    /// A field's placeholder, in the kit's faint text.
    static func fieldPrompt(_ text: LocalizedStringKey) -> Text {
        Text(text).foregroundStyle(Color.textFaint)
    }

    static func fieldPrompt(verbatim text: String) -> Text {
        Text(verbatim: text).foregroundStyle(Color.textFaint)
    }
}
