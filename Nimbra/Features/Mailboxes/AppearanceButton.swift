import SwiftUI

/// 06 · Mailboxes' sun glass button: the app's Appearance (System, Light or Dark), as
/// Settings › Appearance sets it. The frame draws the same sun in both themes, so the
/// choice and the current one are in its menu, and VoiceOver says which is on.
struct AppearanceButton: View {
    @AppStorage(Appearance.key) private var appearance = Appearance.system

    var body: some View {
        Menu {
            Picker(selection: $appearance) {
                ForEach(Appearance.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            } label: {
                Text("Appearance")
            }
        } label: {
            Label { Text("Appearance") } icon: { Icon(.sun) }
        }
        .accessibilityLabel(Text("Appearance"))
        .accessibilityValue(Text(appearance.label))
    }
}
