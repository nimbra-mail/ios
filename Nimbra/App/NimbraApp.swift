import SwiftUI

@main
struct NimbraApp: App {
    @State private var app = NimbraApp.makeModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { flush() }
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
            let app = AppModel.sample()
            app.addingAccount = presentedAtLaunch
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
            await app.flush()
            UIApplication.shared.endBackgroundTask(task)
        }
    }
}
