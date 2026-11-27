import NimbraCore
import SwiftUI

/// 11 · a mailbox's list: All inboxes (each row tagged with its account), a Split Inbox
/// category, Starred, Snoozed and Reminders (by when they come back), Drafts and Sent
/// (who they are to), Done, All Mail, Spam, Trash or a label. What the device keeps at
/// once, then up to date; more as it scrolls; pull to refresh.
struct MailboxListView: View {
    let key: ListingKey
    @Environment(AppModel.self) private var app
    @State private var labelEdit: LabelEdit?
    @State private var labelling: LabelRequest?

    var body: some View {
        @Bindable var app = app
        let listing = key == .allInboxes ? app.allInboxesListing : app.listings[key]
        let threads = listing?.threads ?? []
        ScrollView {
            if !threads.isEmpty {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groups(threads)) { group in
                        Text(group.title)
                            .nimbraText(.overline)
                            .foregroundStyle(Color.textFaint)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 6)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(group.threads) { thread in
                            MailboxThreadLink(thread: thread, mailbox: key.mailbox, isAllInboxes: key == .allInboxes, labelling: $labelling)
                        }
                    }
                    if listing?.nextPage != nil {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .task { await app.loadMoreListing(key) }
                    }
                }
                .padding(.bottom, 24)
            } else if listing?.isFresh == true {
                EmptyMailboxView(mailbox: key.mailbox, name: title)
                    .containerRelativeFrame(.vertical) { height, _ in height * 0.6 }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
        }
        .refreshable { await app.refreshListing(key) }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background(Color.bgList)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavTitle(title: Text(title), subtitle: subtitle)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    app.isSearching = true
                } label: {
                    Label { Text("Search") } icon: { Icon(.search) }
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Mark all as read") { Task { await markAllRead(threads) } }
                    if case .label(let id) = key.mailbox, let label = app.labels(key.account).first(where: { $0.id == id }) {
                        Divider()
                        Button("Rename…") { labelEdit = .rename(label, account: key.account) }
                        Button("Delete label…", role: .destructive) { labelEdit = .delete(label, account: key.account) }
                    }
                } label: {
                    Label { Text("More") } icon: { Icon(.more) }
                }
            }
        }
        .task(id: key) { await app.showListing(key) }
        .labelEditing($labelEdit)
        .sheet(isPresented: $app.isSearching) { SearchView() }
        .sheet(item: $labelling) { LabelsSheet(request: $0) }
    }

    /// The mailbox's name: its own, a label's, or All inboxes.
    private var title: String {
        if key == .allInboxes { return String(localized: "All inboxes") }
        if let title = key.mailbox.title { return String(localized: title) }
        if case .label(let id) = key.mailbox { return app.labels(key.account).first { $0.id == id }?.name ?? "" }
        return ""
    }

    /// Under the title: the accounts All inboxes merges, what a reminder is, else the
    /// account.
    private var subtitle: Text? {
        if key == .allInboxes {
            return Text(verbatim: app.accounts.map(\.name).formatted(.list(type: .and)))
        }
        if key.mailbox == .reminders { return Text("If nobody replies") }
        return app.account(key.account).map { Text(verbatim: $0.name) }
    }

    private func groups(_ threads: [MailThread]) -> [ThreadGroup] {
        switch key.mailbox {
        case .snoozed, .reminders:
            let sorted = threads.sorted { (app.wakeTime($0.id) ?? $0.date) < (app.wakeTime($1.id) ?? $1.date) }
            return ThreadGroup.group(sorted, as: .upcoming) { app.wakeTime($0.id) ?? $0.date }
        case _ where key.mailbox.isInboxLike:
            return ThreadGroup.group(threads, as: .inbox, date: \.date)
        default:
            return ThreadGroup.group(threads, as: .past, date: \.date)
        }
    }

    private func markAllRead(_ threads: [MailThread]) async {
        for thread in threads where thread.isUnread {
            await app.markRead(thread.id)
        }
    }
}

#Preview {
    NavigationStack {
        MailboxListView(key: .allInboxes)
    }
    .environment(AppModel.sample())
}
