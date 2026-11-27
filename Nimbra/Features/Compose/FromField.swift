import SwiftUI

/// From: the account the message is sent from, with its photo once picking, and the
/// menu of accounts (13 · Compose · From). Picking one changes only this message.
struct FromField: View {
    let account: Account?
    let isPicking: Bool
    let pick: () -> Void

    var body: some View {
        ComposeField(label: "From") {
            Button(action: pick) {
                HStack(spacing: isPicking ? 6 : 4) {
                    if isPicking, let account {
                        AvatarView(person: account.person, size: 20)
                    }
                    Text(verbatim: account?.email ?? "")
                        .nimbraText(.subhead)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Icon(.down, size: 14)
                        .foregroundStyle(Color.textTertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("From"))
            .accessibilityValue(Text(verbatim: account?.email ?? ""))
            .accessibilityHint(Text("Picks the account it is sent from"))
        }
    }
}

/// The accounts to send from, as Account Rows in a raised card.
struct FromMenu: View {
    let accounts: [Account]
    let selected: Account.ID
    let pick: (Account.ID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                Button {
                    pick(account.id)
                } label: {
                    PersonRow(
                        person: account.person,
                        title: Text(verbatim: account.shortName),
                        subtitle: account.email,
                        isChecked: account.id == selected,
                        divider: index > 0
                    )
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .background(Color.surfaceRaised, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.borderSubtle))
        .shadow(color: .black.opacity(0.28), radius: 20, y: 16)
    }
}

private extension Account {
    /// What the account is called in the menu: its domain without the ending ("Riangle").
    var shortName: String {
        let first = name.split(separator: ".").first.map(String.init) ?? name
        return first.prefix(1).uppercased() + first.dropFirst()
    }
}
