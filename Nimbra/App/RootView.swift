import SwiftUI

/// Welcome until an account is connected, then the tabs. Keeps the mail current while
/// the app is in front, and presents adding an account and alerts.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app
        Group {
            switch app.phase {
            case .launching: Color.bgList.ignoresSafeArea()
            case .welcome: WelcomeView()
            case .signedIn: MainTabView()
            }
        }
        .animation(.smooth, value: app.phase)
        .task { await app.start() }
        // Starts over when the app comes back to the front or another account is shown;
        // cancelled when it leaves.
        .task(id: Foreground(isActive: scenePhase == .active, phase: app.phase, account: app.accountID)) {
            guard scenePhase == .active else { return }
            await app.stayCurrent()
        }
        .sheet(item: $app.addingAccount) { start in
            AddAccountSheet(start: start)
        }
        // MARK: Compose
        .sheet(item: $app.presentedComposer) { composer in
            ComposeView(composer: composer)
        }
        .onOpenURL { url in app.openMailto(url) }
        // MARK: Sending
        // What waits to be sent goes while the app is in front (`AppModel+Sending`).
        .task(id: Foreground(isActive: scenePhase == .active, phase: app.phase, account: nil)) {
            guard scenePhase == .active else { return }
            await app.keepOutboxMoving()
        }
        // MARK: Notifications
        // Starts over when the snoozes change, to wait for the soonest.
        .task(id: OnTime(isActive: scenePhase == .active, phase: app.phase, snoozed: app.snoozedThreads)) {
            guard scenePhase == .active else { return }
            await app.stayOnTime()
        }
        .sheet(isPresented: $app.isAskingForNotifications, onDismiss: app.notNowNotifications) {
            NotificationAskSheet()
        }
        .sheet(item: $app.notifiedThread) { notified in
            NotifiedThreadView(id: notified.id)
        }
        .notificationsDemo()
        // MARK: Settings
        .sheet(isPresented: $app.showsSettings, onDismiss: app.settingsClosed) {
            SettingsSheet()
        }
        .appliesAppearance()
        .tintsWindows()
        .alert(app.alert?.title ?? "", isPresented: $app.showsRootAlert, presenting: app.alert) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(verbatim: error.message)
        }
    }

    private struct OnTime: Equatable {
        let isActive: Bool
        let phase: AppModel.Phase
        let snoozed: [Account.ID: [MailThread]]
    }

    private struct Foreground: Equatable {
        let isActive: Bool
        let phase: AppModel.Phase
        let account: Account.ID?
    }
}
