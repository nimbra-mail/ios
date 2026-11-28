import NimbraCore
import SwiftUI

/// 08 · Settings · Appearance: the theme (this iPhone's, light or dark, for the whole app),
/// the layout (the size of mail text, the order of a conversation, the subject's line in a
/// list) and how mail is shown: its original formatting, dark emails, remote images, and
/// when a thread counts as read.
struct AppearanceSettingsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(Appearance.key) private var appearance = Appearance.system

    var body: some View {
        SettingsScreen(title: Text("Appearance")) {
            SectionHeader("THEME")
            SegmentedControl(options: Appearance.allCases, selection: $appearance) { Text($0.label) }
            GroupFootnote("System follows your iPhone.")

            SectionHeader("LAYOUT")
            GroupCard {
                SettingsMenuRow(
                    title: Text("Mail text size"), icon: .type, divider: false,
                    options: TextSize.allCases, selection: app.preference(\.textSize)
                ) { Text($0.label) }
                SettingsToggleRow(title: Text("Newest message first"), icon: .sort, isOn: app.preference(\.newestFirst))
                SettingsToggleRow(title: Text("Subject on its own line"), icon: .list, isOn: app.preference(\.subjectOwnLine))
            }
            // The size applies to the text of emails only: the rest of the app follows
            // Dynamic Type.
            GroupFootnote("Text size is for the text of emails.")

            SectionHeader("READING")
            GroupCard {
                SettingsToggleRow(title: Text("Show original formatting"), icon: .brush, divider: false, isOn: app.preference(\.originalView))
                SettingsToggleRow(title: Text("Darken emails in dark theme"), icon: .moon, isOn: app.preference(\.darkEmails))
                SettingsToggleRow(title: Text("Load remote images"), icon: .image, isOn: app.preference(\.loadImages))
                SettingsMenuRow(
                    title: Text("Mark as read"), icon: .eye,
                    options: MarkReadChoice.allCases, selection: app.preference(\.markRead)
                ) { Text($0.label) }
            }
            GroupFootnote("Original formatting shows mail as its sender designed it. Images can tell senders you opened their mail; tracking pixels are never loaded.")
        }
    }
}
