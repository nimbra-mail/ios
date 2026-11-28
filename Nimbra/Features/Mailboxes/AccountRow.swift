import SwiftUI

/// An account in Mailboxes (the kit's Account Row): its avatar, name and address, and its
/// unread inbox threads. The account whose mailboxes are shown is selected.
struct AccountRow: View {
    let account: Account
    let unread: Int
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 12) {
                AccountAvatar(account: account, size: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: account.name)
                        .nimbraText(.body)
                        .foregroundStyle(Color.textPrimary)
                    Text(verbatim: account.email)
                        .nimbraText(.footnote)
                        .foregroundStyle(Color.textTertiary)
                }
                .lineLimit(1)
                Spacer(minLength: 8)
                if unread > 0 {
                    Text(unread, format: .number)
                        .nimbraText(.subhead)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                if isSelected { Rectangle().fill(Color.surfaceSelected) }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Rectangle().fill(Color.borderSubtle).frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
