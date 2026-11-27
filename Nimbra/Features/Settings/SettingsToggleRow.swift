import SwiftUI

/// A List Row with the kit's Switch: the system toggle in the accent, named by the row's
/// title for VoiceOver.
struct SettingsToggleRow: View {
    let title: Text
    var icon: NimbraIcon?
    var divider = true
    @Binding var isOn: Bool

    var body: some View {
        ListRow(title, icon: icon, divider: divider) {
            Toggle(isOn: $isOn) { title }
                .labelsHidden()
                .tint(Color.accentColor)
        }
        .accessibilityRepresentation {
            Toggle(isOn: $isOn) { title }
        }
    }
}
