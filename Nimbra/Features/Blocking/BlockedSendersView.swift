import SwiftUI

/// 12 · Blocked senders: each account's blocked addresses with Unblock. Settings opens it
/// (pushed in its sheet).
struct BlockedSendersView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                footnote(Text("Their mail goes straight to the Blocked label, marked read, and never notifies."))
                    .padding(.bottom, 6)
                ForEach(app.accounts) { account in
                    let blocked = app.blockedSenders[account.id] ?? []
                    if !blocked.isEmpty {
                        SectionHeader("\(account.name.uppercased())")
                        GroupCard {
                            ForEach(Array(blocked.enumerated()), id: \.element) { index, address in
                                BlockedSenderRow(address: address, divider: index > 0) {
                                    Task { await app.unblock(address, in: account.id) }
                                }
                            }
                        }
                    }
                }
                footnote(Text("To block someone, open their message and choose Block sender in the ⋯ menu."))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .background(Color.surfaceRaised)
        .navigationTitle("Blocked senders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavTitle(title: Text("Blocked senders"))
            }
        }
        .task { await app.loadAllBlocked() }
    }

    private func footnote(_ text: Text) -> some View {
        text
            .nimbraText(.footnote)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 2)
    }
}

#Preview {
    NavigationStack { BlockedSendersView() }
        .environment(AppModel.sample())
}
