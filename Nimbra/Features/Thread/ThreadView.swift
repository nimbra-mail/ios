import SwiftUI

/// 03 · Thread: labels, the subject, earlier messages folded, the latest in
/// full, and the actions in a floating glass bar.
struct ThreadView: View {
    let id: MailThread.ID
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var isSnoozing = false
    @State private var reply: ComposeDraft?

    var body: some View {
        if let thread = app.thread(id) {
            content(thread)
        } else {
            // Done or snoozed from here: the thread has left the inbox.
            Color.bgList.onAppear { dismiss() }
        }
    }

    private func content(_ thread: MailThread) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !thread.labels.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(thread.labels, id: \.self) { LabelPill(name: $0) }
                    }
                }
                SubjectTitle(subject: thread.subject)
                Participants(people: thread.participants)
                if thread.messages.count > 1 {
                    FoldedMessages(messages: thread.messages.dropLast())
                }
                if let latest = thread.latest {
                    MessageView(message: latest)
                } else {
                    // Until its messages are read: the snippet the listing has.
                    Text(verbatim: thread.snippet)
                        .nimbraText(.reading)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background(Color.bgList)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await app.toggleStar(id) }
                } label: {
                    Label { Text(thread.isStarred ? "Unstar" : "Star") } icon: {
                        Icon(.star).foregroundStyle(thread.isStarred ? Color.accentAmber : Color.textPrimary)
                    }
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Mark as unread") { Task { await app.markUnread(id) } }
                } label: {
                    Label { Text("More") } icon: { Icon(.more) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ThreadActionBar(
                done: { Task { await app.markDone(id) } },
                snooze: { isSnoozing = true },
                reply: { reply = .reply(to: thread) },
                forward: { reply = .forward(thread) }
            )
        }
        .sheet(isPresented: $isSnoozing) {
            SnoozeSheet(subject: thread.subject) { date, onlyIfNoReply in
                Task { await app.snooze(id, until: date, onlyIfNoReply: onlyIfNoReply) }
            }
        }
        .sheet(item: $reply) { draft in
            ComposeView(draft: draft)
        }
        .task {
            await app.markRead(id)
            await app.loadMessages(id)
        }
    }
}
