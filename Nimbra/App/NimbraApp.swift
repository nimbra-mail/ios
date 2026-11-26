import SwiftUI

@main
struct NimbraApp: App {
    @State private var app = AppModel(
        // Debug builds open signed in with the launch argument `-SignedIn YES`.
        phase: UserDefaults.standard.bool(forKey: "SignedIn") ? .signedIn : .welcome
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
    }
}
