import NimbraCore
import SwiftUI

/// 08 · Settings · Appearance: the theme (this iPhone's, light or dark, for the whole app)
/// and how mail is shown: dark emails, remote images, and when a thread counts as read.
struct AppearanceSettingsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(Appearance.key) private var appearance = Appearance.system

    var body: some View {
        SettingsScreen(title: Text("Appearance")) {
            SectionHeader("THEME")
            SegmentedControl(options: Appearance.allCases, selection: $appearance) { Text($0.label) }
            GroupFootnote("System follows your iPhone.")

            SectionHeader("READING")
            GroupCard {
                SettingsToggleRow(title: Text("Darken emails in dark theme"), icon: .moon, divider: false, isOn: app.preference(\.darkEmails))
                SettingsToggleRow(title: Text("Load remote images"), icon: .image, isOn: app.preference(\.loadImages))
                SettingsMenuRow(
                    title: Text("Mark as read"), icon: .eye,
                    options: MarkReadChoice.allCases, selection: app.preference(\.markRead)
                ) { Text($0.label) }
            }
            GroupFootnote("Images can tell senders you opened their mail. Tracking pixels are never loaded.")
        }
    }
}
