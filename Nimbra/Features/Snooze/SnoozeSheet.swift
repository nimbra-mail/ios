import SwiftUI

/// 05 · Snooze: the quick times, any date and time, and "Only if nobody
/// replies".
struct SnoozeSheet: View {
    let subject: String
    let snooze: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var picksDate = false
    @State private var date = Date.now.addingTimeInterval(24 * 3600)
    @State private var onlyIfNoReply = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Snooze \(Text("until").font(NimbraTextStyle.titleItalic.font))")
                        .nimbraText(.title)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: subject)
                        .nimbraText(.footnote)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)

                GroupCard {
                    ForEach(Array(SnoozeOption.allCases.enumerated()), id: \.element) { index, option in
                        let when = option.date(from: .now)
                        GroupRow(icon: option.icon, iconColor: .accentColor, title: Text(option.title), divider: index > 0) {
                            Text(when, format: .dateTime.weekday(.abbreviated).hour().minute())
                                .nimbraText(.subhead)
                                .foregroundStyle(Color.textTertiary)
                        } action: {
                            snooze(when)
                            dismiss()
                        }
                    }
                }

                GroupCard {
                    GroupRow(icon: .calendar, iconColor: .textSecondary, title: Text("Pick a date and time"), divider: false) {
                        EmptyView()
                    } action: {
                        withAnimation(.smooth) { picksDate.toggle() }
                    }
                    if picksDate {
                        DatePicker("Snooze until", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .tint(Color.accentColor)
                            .padding(.horizontal, 12)
                        Button("Snooze") {
                            snooze(date)
                            dismiss()
                        }
                        .buttonStyle(.glassProminent)
                        .padding(.bottom, 12)
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
            .padding(.top, 24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surfaceRaised)
    }
}
