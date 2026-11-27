import SwiftUI

/// The three tabs under the floating glass tab bar, and the composer it opens.
struct MainTabView: View {
    @State private var tab = AppTab.inbox
    @State private var isComposing = false
    // MARK: Reading
    /// A screen pushed over a tab (a thread) has its own bar at the bottom.
    @State private var hidesTabBar = false

    var body: some View {
        Group {
            switch tab {
            case .inbox: InboxView()
            case .snoozed: SnoozedView()
            case .mailboxes: MailboxesView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !hidesTabBar {
                TabBar(selection: $tab) { isComposing = true }
            }
        }
        .onPreferenceChange(HidesTabBar.self) { hidesTabBar = $0 }
        .sheet(isPresented: $isComposing) {
            ComposeView(draft: .init())
        }
    }
}
