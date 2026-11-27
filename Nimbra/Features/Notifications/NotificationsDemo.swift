import SwiftUI
import UserNotifications

extension View {
    /// Debug builds on the sample mail (`-SignedIn YES`) open these screens at launch, for
    /// screenshots: `-Present snooze` (05 · Snooze), `-Present notifications-ask`
    /// (16 · Ask), `-Present inbox-zero` (07, every thread of the inbox marked Done).
    func notificationsDemo() -> some View {
        #if DEBUG
        modifier(NotificationsDemo())
        #else
        self
        #endif
    }
}

#if DEBUG
private struct NotificationsDemo: ViewModifier {
    @Environment(AppModel.self) private var app
    @State private var snoozing = false
    private let present = UserDefaults.standard.string(forKey: "Present")

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $snoozing) {
                SnoozeSheet(subject: app.inboxThreads.first?.subject ?? "") { _, _ in }
            }
            .task(id: app.phase) {
                guard app.phase == .signedIn, UserDefaults.standard.bool(forKey: "SignedIn") else { return }
                try? await Task.sleep(for: .milliseconds(600))
                switch present {
                case "snooze": snoozing = true
                case "notifications-ask": app.isAskingForNotifications = true
                case "inbox-zero":
                    for thread in app.inboxThreads { await app.markDone(thread.id) }
                case "notify":
                    // Provisional (quiet, no prompt to answer), then a new mail now and a snooze
                    // back in 20 s, through the app's own paths.
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional])
                    await app.loadNotificationSettings()
                    let threads = app.inboxThreads
                    guard threads.count > 1, let account = app.accountID else { return }
                    let first = threads[0]
                    await app.notifier.post(MailNotification(
                        id: MailNotification.id(account: account, thread: first.id.thread), account: account,
                        thread: first.id.thread, title: first.sender?.name ?? "", subtitle: first.subject,
                        body: first.snippet, sound: true
                    ))
                    await app.snooze(threads[1].id, until: .now.addingTimeInterval(20))
                    print("NimbraDemo pending:", await app.notifier.pendingIDs())
                    try? await Task.sleep(for: .seconds(25))
                    // Ids only: what iOS delivered, from the real notification center.
                    print("NimbraDemo delivered:", await app.notifier.deliveredIDs().sorted())
                    print("NimbraDemo pending:", await app.notifier.pendingIDs())
                default: break
                }
            }
    }
}
#endif
