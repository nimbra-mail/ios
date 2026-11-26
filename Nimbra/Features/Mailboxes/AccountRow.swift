import SwiftUI

/// An account in Mailboxes: its avatar, name and address; a check when the
/// inbox shows it.
struct AccountRow: View {
    let account: Account
    let isCurrent: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
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
                Spacer(minLength: 8)
                if isCurrent {
                    Icon(.done, size: 18).foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Divider().overlay(Color.borderSubtle) }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
