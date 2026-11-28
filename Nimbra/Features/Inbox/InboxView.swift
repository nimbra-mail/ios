import SwiftUI

/// 02 · Inbox: the account's inbox (a Gmail account's split by category), newest first,
/// every thread or only the unread ones (the Filter); Inbox zero when it is empty.
struct InboxView: View {
    @Environment(AppModel.self) private var app
    // MARK: Reading
    /// Debug builds open a sample thread at launch, for screenshots: `-Open launch`.
    @State private var path: [MailThread.ID] = InboxView.openedAtLaunch

    var body: some View {
        @Bindable var app = app
        let threads = app.inboxThreads
        let shown = app.inboxFilter.apply(threads)
        let listing = app.inboxListing
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if app.hasSplitInbox(app.accountID) {
                        SplitChips()
                            .padding(.top, 12)
                            .padding(.bottom, 16)
                    }
                    if !threads.isEmpty {
                        FilterControl(options: InboxFilter.allCases, selection: $app.inboxFilter) {
                            Text($0.label)
                        } count: { filter in
                            filter == .unread ? app.unreadCount(app.split) : nil
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, app.hasSplitInbox(app.accountID) ? 2 : 12)
                        .padding(.bottom, 6)
                        if shown.isEmpty {
                            Text("No unread mail")
                                .nimbraText(.footnote)
                                .foregroundStyle(Color.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                        ThreadSections(threads: shown)
                        if listing?.nextPage != nil {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 24)
                                .task { await app.loadMoreInbox() }
                        }
                    } else if listing?.isFresh == true {
                        // Inbox zero fills the screen behind the bar and chips (below).
                        EmptyView()
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                }
            }
            .refreshable {
                if let key = app.inboxKey { await app.refresh(key) }
            }
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .background {
                if threads.isEmpty, listing?.isFresh == true {
                    InboxZeroView()
                } else {
                    Color.bgList
                        .ignoresSafeArea()
                }
            }
            .toolbar { InboxToolbar() }
            .navigationTitle("Inbox")
            .toolbarTitleDisplayMode(.inline)
            .navigationDestination(for: MailThread.ID.self) { id in
                ThreadView(id: id)
            }
        }
        .sheet(isPresented: $app.isSearching) { SearchView() }
    }
}

extension InboxView {
    // MARK: Reading
    private static var openedAtLaunch: [MailThread.ID] {
        #if DEBUG
        if let thread = UserDefaults.standard.string(forKey: "Open") {
            return [MailThread.ID(account: SampleData.work.id, thread: thread)]
        }
        #endif
        return []
    }
}

#Preview {
    MainTabView().environment(AppModel.sample())
}
