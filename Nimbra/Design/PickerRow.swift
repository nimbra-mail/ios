import SwiftUI

/// The kit's List Row with a menu picker: the title in Body, the value in Subhead and the
/// up-and-down mark at the end (Security: SSL/TLS).
struct PickerRow<Value: Hashable, Options: View>: View {
    let title: LocalizedStringKey
    let value: Text
    @Binding var selection: Value
    var divider = true
    @ViewBuilder let options: Options

    var body: some View {
        Menu {
            Picker(selection: $selection) { options } label: { Text(title) }
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .nimbraText(.body)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                value
                    .nimbraText(.subhead)
                    .foregroundStyle(Color.textTertiary)
                Icon(.updown, size: 16)
                    .foregroundStyle(Color.textFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(minHeight: 50)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if divider { Divider().overlay(Color.borderSubtle) }
        }
        .accessibilityElement(children: .combine)
    }
}
