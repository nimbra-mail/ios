import SwiftUI

/// 06 · Mailboxes: the accounts, Split Inbox and the mailboxes.
struct MailboxesView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mailboxes")
                        .nimbraText(.largeTitle)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 8)

                    overline("ACCOUNTS")
                    GroupCard {
                        GroupRow(icon: .mail, iconColor: .accentColor, title: Text("All inboxes"), divider: false) {
                            count(app.threads.count(where: \.isUnread))
                        }
                        ForEach(app.accounts) { account in
                            AccountRow(account: account, isCurrent: account.id == app.accountID) {
                                app.accountID = account.id
                            }
                        }
                    }

                    overline("SPLIT INBOX")
                    GroupCard {
                        ForEach(Array(SplitCategory.allCases.enumerated()), id: \.element) { index, category in
                            GroupRow(icon: category.icon, iconColor: .textSecondary, title: Text(category.title), divider: index > 0) {
                                count(app.inbox(category).count)
                            } action: {
                                app.split = category
                            }
                        }
                    }

                    overline("MAILBOX")
                    GroupCard {
                        GroupRow(icon: .star, iconColor: .textSecondary, title: Text("Starred"), divider: false) {
                            count(app.threads.count(where: \.isStarred))
                        }
                        GroupRow(icon: .clock, iconColor: .textSecondary, title: Text("Snoozed"), divider: true) {
                            count(app.snoozed.count)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .background(Color.bgList)
            .navigationTitle("Mailboxes")
            .toolbar(removing: .title)
        }
    }

    private func overline(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .nimbraText(.overline)
            .foregroundStyle(Color.textFaint)
            .padding(.leading, 4)
            .padding(.top, 10)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func count(_ n: Int) -> some View {
        if n > 0 {
            Text(n, format: .number)
                .nimbraText(.subhead)
                .foregroundStyle(Color.textTertiary)
        }
    }
}
