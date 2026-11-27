import SwiftUI

/// A thread opened from its notification, over whatever was on screen: 03 · Thread with a
/// close button, so the tab and the list stay where they were.
struct NotifiedThreadView: View {
    let id: MailThread.ID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ThreadView(id: id)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Label { Text("Close") } icon: { Icon(.x) }
                        }
                    }
                }
        }
    }
}
