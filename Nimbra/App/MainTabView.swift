import SwiftUI

/// The three tabs under the floating glass tab bar, and the composer it opens.
struct MainTabView: View {
    @State private var tab = AppTab.inbox
    @State private var isComposing = false

    var body: some View {
        Group {
            switch tab {
            case .inbox: InboxView()
            case .snoozed: SnoozedView()
            case .mailboxes: MailboxesView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            TabBar(selection: $tab) { isComposing = true }
        }
        .sheet(isPresented: $isComposing) {
            ComposeView(draft: .init())
        }
    }
}
