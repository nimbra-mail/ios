import SwiftUI

/// 02 · Inbox: the account's inbox (a Gmail account's split by category), newest first;
/// Inbox zero when it is empty.
struct InboxView: View {
    @Environment(AppModel.self) private var app
    // MARK: Reading
    /// Debug builds open a sample thread at launch, for screenshots: `-Open launch`.
    @State private var path: [MailThread.ID] = InboxView.openedAtLaunch

    var body: some View {
        @Bindable var app = app
        let threads = app.inboxThreads
        let listing = app.inboxListing
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    InboxHeader(title: "Inbox")
                        .padding(.bottom, app.hasSplitInbox(app.accountID) ? 0 : 14)
                    if app.hasSplitInbox(app.accountID) {
                        SplitChips()
                            .padding(.top, 18)
                            .padding(.bottom, 10)
                    }
                    if !threads.isEmpty {
                        ThreadSections(threads: threads)
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
                }
            }
            .toolbar { InboxToolbar() }
            .navigationTitle("Inbox")
            .toolbarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
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
