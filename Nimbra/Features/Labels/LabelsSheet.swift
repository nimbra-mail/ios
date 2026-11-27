import NimbraCore
import SwiftUI

/// 15 · Labels: the account's labels with a check on the thread's, each tapped on or off
/// (`relabel`); or, to move it, the label it goes to (`moveToLabel`). New label makes one
/// and puts it on.
struct LabelsSheet: View {
    let request: LabelRequest
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var labelEdit: LabelEdit?

    var body: some View {
        let id = request.thread
        let labels = app.labels(id.account)
        let applied = app.labelIDs(of: id)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavTitle(title: title, subtitle: app.thread(id).map { Text(verbatim: $0.subject) })
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 4)

                if !labels.isEmpty || showsInbox {
                    GroupCard {
                        if showsInbox {
                            Button {
                                dismiss()
                                Task { await app.moveToInbox(id) }
                            } label: {
                                MailboxRow(icon: .inbox, iconColor: .accentColor, title: Text("Inbox"), divider: false)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(labels) { label in
                            row(label, isApplied: applied.contains(label.id), divider: showsInbox || label.index > 0)
                        }
                    }
                } else {
                    Text(request.mode == .label ? "You have no labels yet." : "Nowhere to move this to yet.")
                        .nimbraText(.subhead)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 4)
                }

                GroupCard {
                    Button {
                        labelEdit = .new(account: id.account, thread: id)
                    } label: {
                        MailboxRow(icon: .plus, iconColor: .accentColor, title: Text("New label"), titleColor: .accentColor, divider: false)
                    }
                    .buttonStyle(.plain)
                }

                footnote
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        // As tall as 15 · Labels draws it (538 of 874 pt), and all of the screen for many labels.
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surfaceRaised)
        .labelEditing($labelEdit)
    }

    private var title: Text {
        request.mode == .label ? Text("Labels") : Text("Move to")
    }

    /// Move to offers the inbox where the thread is not in it (Done, Spam, Trash, a label).
    private var showsInbox: Bool {
        request.mode == .move && !app.source(of: request.thread).isInboxLike
    }

    private var footnote: Text {
        let name = app.account(request.thread.account)?.name ?? ""
        return app.account(request.thread.account)?.kind == .gmail
            ? Text("Labels belong to \(name). Use “Parent/Child” to nest one.")
            : Text("Folders belong to \(name). Use “Parent/Child” to nest one.")
    }

    private func row(_ label: MailLabel, isApplied: Bool, divider: Bool) -> some View {
        Button {
            switch request.mode {
            case .label:
                Task { await app.toggleLabel(label, on: request.thread) }
            case .move:
                dismiss()
                Task { await app.move(request.thread, to: label) }
            }
        } label: {
            HStack(spacing: 12) {
                Icon(.tag).foregroundStyle(label.tint)
                Text(verbatim: label.name)
                    .nimbraText(.body)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if request.mode == .label, isApplied {
                    Icon(.done).foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(minHeight: 50)
            .contentShape(.rect)
            .overlay(alignment: .top) {
                if divider { Rectangle().fill(Color.borderSubtle).frame(height: 1) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(request.mode == .label && isApplied ? .isSelected : [])
    }
}
