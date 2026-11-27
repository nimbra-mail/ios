import SwiftUI

/// A List Row that picks from a pull-down menu (Check for mail, Undo send): the value on
/// the right with the up-and-down mark, the picked one checked in the menu.
struct SettingsMenuRow<Value: Hashable & Identifiable>: View {
    let title: Text
    let icon: NimbraIcon
    var divider = true
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> Text

    var body: some View {
        Menu {
            Picker(selection: $selection) {
                ForEach(options) { option in
                    label(option).tag(option)
                }
            } label: {
                title
            }
        } label: {
            ListRow(title, icon: icon, divider: divider) {
                ListRowValue(label(selection))
                Icon(.updown, size: 16).foregroundStyle(Color.textFaint)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
