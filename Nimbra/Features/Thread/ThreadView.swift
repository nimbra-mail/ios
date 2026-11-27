import NimbraCore
import QuickLook
import SwiftUI

/// 03 · Thread: labels, the subject, earlier messages folded, the latest in full, and the
/// actions in a floating glass bar. Opening it reads its messages and marks it read as
/// Preferences say; links show their address before they leave the app.
struct ThreadView: View {
    let id: MailThread.ID
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isSnoozing = false
    /// Earlier messages opened in full.
    @State private var expanded: Set<Message.ID> = []
    /// A tapped web link, waiting for the person to open it.
    @State private var link: URL?
    /// A list's unsubscribe page, waiting for the person to open it.
    @State private var unsubscribePage: URL?
    @State private var previewURL: URL?
    /// The thread was on screen: when it is gone after that, it left the mailbox.
    @State private var wasShown = false
    // MARK: Mailboxes
    @State private var labelling: LabelRequest?

    var body: some View {
        if let thread = app.thread(id) {
            content(thread)
                .onAppear { wasShown = true }
        } else {
            // Done, trashed or snoozed from here: the thread has left the mailbox. (Before
            // it was shown, it is still being listed: a link or a launch can open it first.)
            Color.bgList.onAppear { if wasShown { dismiss() } }
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
                Participants(people: thread.participants, messageCount: max(thread.messageCount, thread.messages.count))
                messages(thread)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            // Links in the reader come here rather than straight to Safari.
            .environment(\.openURL, OpenURLAction { url in
                follow(url, in: thread)
                return .handled
            })
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background(Color.bgList)
        .toolbarRole(.editor)
        .toolbar { toolbar(thread) }
        .safeAreaInset(edge: .bottom) {
            ThreadActionBar(
                done: { Task { await app.markDoneFromThread(id) } },
                snooze: { isSnoozing = true },
                reply: { answer(.reply) },
                forward: { answer(.forward) }
            )
        }
        .sheet(isPresented: $isSnoozing) {
            SnoozeSheet(subject: thread.subject) { date, onlyIfNoReply in
                Task { await app.snooze(id, until: date, onlyIfNoReply: onlyIfNoReply) }
            }
        }
        .confirmationDialog(Text(verbatim: link?.host() ?? ""), isPresented: isPresent($link), titleVisibility: .visible, presenting: link) { url in
            Button("Open in Safari") { openURL(url) }
            Button("Copy Link") { UIPasteboard.general.url = url }
            Button("Cancel", role: .cancel) {}
        } message: { url in
            Text(verbatim: url.absoluteString)
        }
        .confirmationDialog("Unsubscribe", isPresented: isPresent($unsubscribePage), titleVisibility: .visible, presenting: unsubscribePage) { url in
            Button("Open \(url.host() ?? "")") { openURL(url) }
            Button("Cancel", role: .cancel) {}
        } message: { url in
            Text("Opens \(url.host() ?? "") in your browser to unsubscribe.")
        }
        // MARK: Mailboxes
        .sheet(item: $labelling) { LabelsSheet(request: $0) }
        .quickLookPreview($previewURL)
        .preference(key: HidesTabBar.self, value: true)
        .task(id: id) { await app.open(id) }
        .onDisappear { AttachmentFiles.remove(for: id) }
    }

    // MARK: Messages

    @ViewBuilder
    private func messages(_ thread: MailThread) -> some View {
        if let latest = thread.latest {
            ForEach(Folding.runs(Array(thread.messages.dropLast()), expanded: expanded), id: \.first?.id) { run in
                if run.count == 1, let message = run.first, expanded.contains(message.id) {
                    fullMessage(message)
                } else {
                    FoldedMessages(messages: run) { expanded.insert($0.id) }
                }
            }
            fullMessage(latest)
        } else if app.unreadable.contains(id) {
            VStack(alignment: .leading, spacing: 12) {
                Text("This message could not be loaded.")
                    .nimbraText(.reading)
                    .foregroundStyle(Color.textSecondary)
                Button("Try again") { Task { await app.loadMessages(id) } }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
            }
        } else {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading message…")
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fullMessage(_ message: Message) -> some View {
        MessageView(
            message: message, thread: id,
            open: { follow($0, in: app.thread(id)) },
            preview: { previewURL = $0 }
        )
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private func toolbar(_ thread: MailThread) -> some ToolbarContent {
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
                more(thread)
            } label: {
                Label { Text("More") } icon: { Icon(.more) }
            }
        }
    }

    @ViewBuilder
    private func more(_ thread: MailThread) -> some View {
        Button { answer(.replyAll) } label: {
            Label { Text("Reply all") } icon: { Icon(.replyAll) }
        }
        Button { Task { await app.keepUnread(id) } } label: {
            Label { Text("Mark as unread") } icon: { Icon(.mail) }
        }
        // MARK: Mailboxes · Label, Move to, Star, Block sender
        ThreadMailboxMenu(id: id, labelling: $labelling)
        if let latest = thread.latest, latest.html != nil {
            Button { app.switchView(latest) } label: {
                if app.showsOriginal(latest) {
                    Label { Text("Switch to reader view") } icon: { Icon(.list) }
                } else {
                    Label { Text("Switch to original") } icon: { Icon(.news) }
                }
            }
        }
        if let link = thread.messages.last(where: { $0.unsubscribe != nil })?.unsubscribe {
            Button { unsubscribe(link, in: thread) } label: {
                Label { Text("Unsubscribe") } icon: { Icon(.ban) }
            }
        }
        Divider()
        if app.outsideInbox(id) != nil {
            Button { Task { await app.moveToInbox(id) } } label: {
                Label { Text("Move to Inbox") } icon: { Icon(.inbox) }
            }
        }
        if app.outsideInbox(id) != .trash {
            Button(role: .destructive) { Task { await app.trash(id) } } label: {
                Label { Text("Move to trash") } icon: { Icon(.trash) }
            }
        }
    }

    // MARK: Leaving the thread

    /// A web link shows its address first; a mail link opens a new message from the
    /// thread's account.
    private func follow(_ url: URL, in thread: MailThread?) {
        guard MailNavigation.leavesApp(url) else { return }
        if url.scheme?.lowercased() == "mailto" {
            _ = app.openMailto(url)
        } else {
            link = url
        }
    }

    /// The list's page opens in the browser after the person confirms (the page asks
    /// again); a mail one prepares the exact message the list asks for.
    private func unsubscribe(_ link: String, in thread: MailThread) {
        switch unsubscribeAction(link: link) {
        case .web(let address):
            if let url = URL(string: address), MailNavigation.leavesApp(url) { unsubscribePage = url }
        case .mail(let to, let subject, let body):
            // Sent exactly as the list asks, from the thread's account, without a signature.
            Task { await app.startUnsubscribe(to: to, subject: subject, body: body, account: id.account) }
        case nil:
            app.alert = .invalid(String(localized: "This list’s unsubscribe address is not valid."))
        }
    }

    private func answer(_ answer: Answer) {
        Task { await app.startAnswer(answer, to: id) }
    }

    /// Presented while `value` is set; dismissing clears it.
    private func isPresent<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}
