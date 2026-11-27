import NimbraCore
import SwiftUI

/// 05 · Snooze: "Snooze until" over the subject in the bar, the engine's quick times with
/// when each comes back, any day and time, and "Only if nobody replies" (a reminder). The
/// switch and the time typed are kept for next time, as the Mac keeps them.
struct SnoozeSheet: View {
    let subject: String
    /// When, and whether only if nobody replies (a reminder).
    let snooze: (Date, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Snooze.OnlyIfNoReply") private var onlyIfNoReply = false
    @State private var choices = SnoozeChoice.quickTimes()
    @State private var picksDate = false
    /// The sheet is as tall as the times (any text size); the calendar opens it full height.
    @State private var height: CGFloat = 454

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                title
                GroupCard {
                    ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                        GroupRow(icon: choice.icon, iconColor: .accentColor, title: Text(choice.title), divider: index > 0) {
                            Text(verbatim: SnoozeTimeText.hint(choice.until, now: .now))
                                .nimbraText(.subhead)
                                .foregroundStyle(Color.textTertiary)
                        } action: {
                            pick(choice.until)
                        }
                    }
                }
                GroupCard {
                    GroupRow(icon: .calendar, iconColor: .textSecondary, title: Text("Pick a date and time"), divider: false) {
                        EmptyView()
                    } action: {
                        withAnimation(.smooth) { picksDate.toggle() }
                    }
                    .accessibilityValue(picksDate ? Text("Shown") : Text("Hidden"))
                    if picksDate {
                        SnoozeDatePicker { pick($0) }
                            .overlay(alignment: .top) { Divider().overlay(Color.borderSubtle) }
                    }
                    Toggle(isOn: $onlyIfNoReply) {
                        HStack(spacing: 12) {
                            Icon(.bell).foregroundStyle(Color.textSecondary)
                            Text("Only if nobody replies")
                                .nimbraText(.body)
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                    .tint(Color.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .overlay(alignment: .top) { Divider().overlay(Color.borderSubtle) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 12)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents(picksDate ? [.large] : [.height(height)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surfaceRaised)
        .onAppear { choices = SnoozeChoice.quickTimes() }
    }

    /// The bar's title: Headline, the subject in Overline under it.
    private var title: some View {
        VStack(spacing: 0) {
            Text("Snooze until")
                .nimbraText(.headline)
                .foregroundStyle(Color.textPrimary)
            Text(verbatim: subject.uppercased())
                .nimbraText(.overline)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func pick(_ date: Date) {
        snooze(date, onlyIfNoReply)
        dismiss()
    }
}

#Preview {
    Color.bgList.sheet(isPresented: .constant(true)) {
        SnoozeSheet(subject: "Q4 launch plan, final review") { _, _ in }
    }
}
