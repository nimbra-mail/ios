import SwiftUI

/// The kit's Account Row in Settings: the photo (28), name and address, "Default" for the
/// default when there are several, and the chevron.
struct SettingsAccountRow: View {
    let account: Account
    let showsDefault: Bool
    let divider: Bool

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(person: account.person, size: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: account.name)
                    .nimbraText(.body)
                    .foregroundStyle(Color.textPrimary)
                Text(verbatim: account.email)
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsDefault {
                ListRowValue(Text("Default"))
            }
            ListRowChevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(.rect)
        .overlay(alignment: .top) {
            if divider { Divider().overlay(Color.borderSubtle) }
        }
        .accessibilityElement(children: .combine)
    }
}
