import SwiftUI

/// Search: threads whose sender, subject or text has every word typed.
struct SearchView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(app.searchResults) { thread in
                        NavigationLink(value: thread.id) {
                            ThreadRow(thread: thread)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(Color.bgList)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search mail"))
            .navigationDestination(for: MailThread.ID.self) { ThreadView(id: $0) }
            .task(id: query) {
                // Waits for typing to pause before asking the server.
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                await app.search(query)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }
}
