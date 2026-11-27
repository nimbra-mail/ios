import SwiftUI

@main
struct NimbraApp: App {
    @State private var app: AppModel
    @Environment(\.scenePhase) private var scenePhase
    // MARK: Notifications
    /// Answers notifications; the center keeps its delegate weakly.
    @State private var responder: NotificationResponder

    init() {
        let app = NimbraApp.makeModel()
        _app = State(initialValue: app)
        let responder = NotificationResponder(app: app)
        responder.start()
        _responder = State(initialValue: responder)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { flush() }
        }
        // MARK: Notifications
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) { [app] in
            await app.runBackgroundRefresh()
        }
    }

    /// Debug builds open a sheet straight away, for screenshots: `-Present add-account`
    /// (09 · Add account) or `-Present other-address` (10 · IMAP setup).
    private static var presentedAtLaunch: AddAccountStart? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "Present") {
        case "add-account": .providers
        case "other-address": .otherAddress
        default: nil
        }
        #else
        nil
        #endif
    }

    /// The real engine, except in the unit tests' host (which make their own engines, and
    /// must not open the app's folders or Keychain) and, in debug builds, the demo launch
    /// with the sample mail (`-SignedIn YES`, for screenshots).
    private static func makeModel() -> AppModel {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .sample(signedIn: false)
        }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "SignedIn") {
            let signedOut: Set<Account.ID> = UserDefaults.standard.string(forKey: "SettingsScreen") == "signed-out" ? [SampleData.personal.id] : []
            let app = AppModel.sample(offline: UserDefaults.standard.bool(forKey: "Offline"), signedOut: signedOut)
            app.addingAccount = presentedAtLaunch
            // MARK: Compose
            app.startComposeDemo()
            // MARK: Settings: `-Present settings` (and `-SettingsScreen …`, see `SettingsRoute`).
            app.showsSettings = UserDefaults.standard.string(forKey: "Present") == "settings"
            app.signedOut = signedOut
            return app
        }
        #endif
        let app = AppModel()
        app.addingAccount = presentedAtLaunch
        return app
    }

    /// Writes what waits to be written while iOS still gives the app time. The engine
    /// stops writing after a few seconds, well within what a background task is given.
    private func flush() {
        let task = UIApplication.shared.beginBackgroundTask(withName: "Saving mail")
        Task {
            await app.enteredBackground()
            await app.flush()
            UIApplication.shared.endBackgroundTask(task)
        }
    }
}
