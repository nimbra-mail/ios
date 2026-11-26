import SwiftUI

/// 02 · Inbox: the split inbox, newest first; Inbox zero when it is empty.
struct InboxView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        let threads = app.inbox(app.split)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    InboxHeader(title: "Inbox")
                    SplitChips(selection: $app.split)
                        .padding(.top, 18)
                        .padding(.bottom, 10)
                    if threads.isEmpty {
                        InboxZeroView()
                            .containerRelativeFrame(.vertical) { height, _ in height * 0.72 }
                    } else {
                        ThreadSections(threads: threads)
                    }
                }
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
    MainTabView().environment(AppModel(phase: .signedIn))
}
