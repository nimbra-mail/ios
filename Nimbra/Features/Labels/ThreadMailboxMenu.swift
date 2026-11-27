import SwiftUI

/// The thread ⋯ menu's Label, Move to, Star and Block sender (12 · Block sender), after the
/// hairline the design draws before Block sender.
struct ThreadMailboxMenu: View {
    let id: MailThread.ID
    /// The Labels sheet, presented by the screen the menu is on.
    @Binding var labelling: LabelRequest?
    @Environment(AppModel.self) private var app

    var body: some View {
        Button {
            labelling = LabelRequest(thread: id, mode: .label)
        } label: {
            Label { Text("Label") } icon: { Image(NimbraIcon.tag.rawValue) }
        }
        Button {
            labelling = LabelRequest(thread: id, mode: .move)
        } label: {
            Label { Text("Move to") } icon: { Image(NimbraIcon.folder.rawValue) }
        }
        let starred = app.thread(id)?.isStarred ?? false
        Button {
            Task { await app.toggleStar(id) }
        } label: {
            Label { Text(starred ? "Remove star" : "Star") } icon: { Image(NimbraIcon.star.rawValue) }
        }
        Divider()
        if app.isBlocked(id) {
            Button {
                Task { await app.unblockSender(of: id) }
            } label: {
                Label { Text("Unblock sender") } icon: { Image(NimbraIcon.ban.rawValue) }
            }
        } else {
            Button(role: .destructive) {
                Task { await app.blockSender(of: id) }
            } label: {
                Label { Text("Block sender") } icon: { Image(NimbraIcon.ban.rawValue) }
            }
        }
    }
}
