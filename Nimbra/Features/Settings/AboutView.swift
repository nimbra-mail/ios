import NimbraCore
import SwiftUI

/// 08 · Settings · About: the app and engine versions, the website, privacy and terms.
struct AboutView: View {
    var body: some View {
        SettingsScreen(title: Text("About")) {
            VStack(spacing: 8) {
                Image(.appIconPreview)
                    .resizable()
                    .frame(width: 88, height: 88)
                    .clipShape(.rect(cornerRadius: 19.766))
                    .padding(.bottom, 4)
                    .accessibilityHidden(true)
                Text(verbatim: "Nimbra")
                    .nimbraText(.title)
                    .foregroundStyle(Color.textPrimary)
                Text("Version \(Bundle.main.version) · Engine \(coreVersion())")
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .accessibilityElement(children: .combine)

            GroupCard {
                link(Text("Visit website"), icon: .link, to: "https://nimbra.me", value: "nimbra.me", divider: false)
                link(Text("Privacy"), icon: .lock, to: "https://nimbra.me/privacy")
                link(Text("Terms"), icon: .file, to: "https://nimbra.me/terms")
            }
        }
    }

    private func link(_ title: Text, icon: NimbraIcon, to address: String, value: String? = nil, divider: Bool = true) -> some View {
        Link(destination: URL(string: address)!) {
            ListRow(title, icon: icon, divider: divider) {
                if let value { ListRowValue(Text(verbatim: value)) }
                ListRowChevron()
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
    }
}
