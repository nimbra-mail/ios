import SwiftUI

/// 02 · Inbox: the account's inbox (a Gmail account's split by category), newest first;
/// Inbox zero when it is empty.
struct InboxView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        let threads = app.inboxThreads
        let listing = app.inboxListing
        NavigationStack {
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
                        InboxZeroView()
                            .containerRelativeFrame(.vertical) { height, _ in height * 0.72 }
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
            .background(Color.bgList)
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

#Preview {
    MainTabView().environment(AppModel.sample())
}
