import SwiftUI

/// 06 · Mailboxes · Edit accounts: the accounts with the system's reorder handles, then Add
/// account, and what the order is for. The order is every list of accounts' (here, All
/// inboxes and From in Compose).
struct AccountOrderList: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        List {
            Section {
                ForEach(app.accounts) { account in
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
                    }
                    .padding(.vertical, 1)
                    .accessibilityElement(children: .combine)
                }
                .onMove { source, destination in
                    Task { await app.moveAccounts(from: source, to: destination) }
                }
                .listRowBackground(Color.surfaceHover)

                Button {
                    app.addingAccount = .providers
                } label: {
                    HStack(spacing: 16) {
                        Icon(.plus).foregroundStyle(Color.accentColor)
                        Text("Add account")
                            .nimbraText(.body)
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.leading, 4)
                }
                .listRowBackground(Color.surfaceHover)
            } header: {
                SectionHeader("ACCOUNTS")
                    .padding(.leading, -20)
            } footer: {
                Text("Drag an account to change its place here, in All inboxes and in Compose.")
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.leading, -16)
            }
            .listRowSeparatorTint(Color.borderSubtle)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .environment(\.editMode, .constant(.active))
    }
}
