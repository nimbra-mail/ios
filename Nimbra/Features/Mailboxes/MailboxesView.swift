import NimbraCore
import SwiftUI

/// 06 · Mailboxes: All inboxes and the accounts, then the selected account's Split Inbox,
/// mailboxes and labels, in the engine's order as the Mac's sidebar lists them. Each opens
/// its list.
struct MailboxesView: View {
    @Environment(AppModel.self) private var app
    @State private var path = NavigationPath()
    @State private var labelEdit: LabelEdit?
    #if DEBUG
    /// The demo launch's `-Present blocked-senders`, for screenshots of 12 · Blocked senders
    /// (Settings opens it in the app).
    @State private var showsBlocked = UserDefaults.standard.string(forKey: "Present") == "blocked-senders"
    #endif

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    accounts
                    if let account = app.account {
                        sections(of: account)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .background(Color.bgList)
            .refreshable {
                if let id = app.accountID { await app.showMailboxes(id) }
            }
            .navigationTitle("Mailboxes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NavTitle(title: Text("Mailboxes"))
                }
            }
            .navigationDestination(for: ListingKey.self) { key in
                MailboxListView(key: key)
            }
            .navigationDestination(for: MailThread.ID.self) { id in
                ThreadView(id: id)
            }
            .task(id: app.accountID) {
                guard let id = app.accountID else { return }
                await app.showMailboxes(id)
            }
            .labelEditing($labelEdit)
        }
        #if DEBUG
        .sheet(isPresented: $showsBlocked) {
            NavigationStack { BlockedSendersView() }
        }
        #endif
    }

    // MARK: Accounts

    private var accounts: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("ACCOUNTS")
            GroupCard {
                if app.accounts.count > 1 {
                    NavigationLink(value: ListingKey.allInboxes) {
                        MailboxRow(icon: .mail, iconColor: .accentColor, title: Text("All inboxes"), count: app.allInboxesUnread, divider: false)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(app.accounts) { account in
                    AccountRow(account: account, unread: app.inboxUnread(account.id), isSelected: account.id == app.accountID) {
                        Task { await app.selectAccount(account.id) }
                    }
                }
            }
        }
    }

    // MARK: The selected account

    @ViewBuilder
    private func sections(of account: Account) -> some View {
        let name = account.name.uppercased()
        let split = app.mailboxes(account.id, in: .split)
        if !split.isEmpty {
            SectionHeader("SPLIT INBOX · \(name)")
            GroupCard {
                ForEach(Array(split.enumerated()), id: \.element.mailbox) { index, entry in
                    link(entry.mailbox, in: account, divider: index > 0)
                }
            }
        }

        SectionHeader("MAILBOX · \(name)")
        GroupCard {
            ForEach(Array(app.mailboxes(account.id, in: .mailboxes).enumerated()), id: \.element.mailbox) { index, entry in
                link(entry.mailbox, in: account, divider: index > 0)
            }
        }

        // An account with its own servers has folders, as the Mac calls them.
        SectionHeader(account.kind == .gmail ? "LABELS · \(name)" : "FOLDERS · \(name)")
        GroupCard {
            ForEach(app.labels(account.id)) { label in
                NavigationLink(value: ListingKey(account: account.id, mailbox: .label(id: label.id))) {
                    MailboxRow(
                        icon: .tag, iconColor: label.tint, title: Text(verbatim: label.name),
                        count: app.count(.label(id: label.id), in: account.id), divider: label.index > 0
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Rename…") { labelEdit = .rename(label, account: account.id) }
                    Button("Delete label…", role: .destructive) { labelEdit = .delete(label, account: account.id) }
                }
            }
            Button {
                labelEdit = .new(account: account.id, thread: nil)
            } label: {
                MailboxRow(icon: .plus, iconColor: .accentColor, title: Text("New label"), titleColor: .accentColor, divider: !app.labels(account.id).isEmpty)
            }
            .buttonStyle(.plain)
        }
    }

    private func link(_ mailbox: Mailbox, in account: Account, divider: Bool) -> some View {
        NavigationLink(value: ListingKey(account: account.id, mailbox: mailbox)) {
            MailboxRow(
                icon: mailbox.icon, title: mailbox.title.map { Text($0) } ?? Text(verbatim: ""),
                count: app.count(mailbox, in: account.id), divider: divider
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MailboxesView().environment(AppModel.sample())
}
