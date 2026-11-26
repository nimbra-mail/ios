import SwiftUI

/// Snoozed threads, the soonest back first.
struct SnoozedView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    InboxHeader(title: "Snoozed")
                        .padding(.bottom, 14)
                    if app.snoozed.isEmpty {
                        Text("Nothing snoozed. Snooze a thread to bring it back when you need it.")
                            .nimbraText(.subhead)
                            .foregroundStyle(Color.textTertiary)
                            .padding(.horizontal, 20)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(app.snoozed) { thread in
                                NavigationLink(value: thread.id) {
                                    ThreadRow(thread: thread)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .background(Color.bgList)
            .navigationTitle("Snoozed")
            .toolbar(removing: .title)
            .navigationDestination(for: MailThread.ID.self) { ThreadView(id: $0) }
        }
    }
}
