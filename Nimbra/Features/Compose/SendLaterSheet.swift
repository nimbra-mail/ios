import NimbraCore
import SwiftUI

/// 13 · Compose · Send later: the engine's times, any date and time, and honest words
/// about when it goes: iOS runs Nimbra in the background only now and then.
struct SendLaterSheet: View {
    let subject: String
    let times: [SendLaterTime]
    let schedule: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var picksDate = false
    @State private var date = Date.now.addingTimeInterval(3600)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text("Send later")
                        .nimbraText(.headline)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: (subject.isEmpty ? String(localized: "New message") : subject).uppercased())
                        .nimbraText(.overline)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 4)

                GroupCard {
                    ForEach(Array(times.enumerated()), id: \.element) { index, time in
                        let when = Date(milliseconds: time.atMs)
                        GroupRow(icon: time.kind.icon, iconColor: .accentColor, title: Text(time.kind.title), divider: index > 0) {
                            Text(verbatim: time.kind.label(when))
                                .nimbraText(.subhead)
                                .foregroundStyle(Color.textTertiary)
                        } action: {
                            schedule(when)
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
                        DatePicker("Send at", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .tint(Color.accentColor)
                            .padding(.horizontal, 12)
                        Button("Send later") {
                            schedule(date)
                            dismiss()
                        }
                        .buttonStyle(.glassProminent)
                        .padding(.bottom, 12)
                    }
                }

                Text("Nimbra sends it from this iPhone at that time, or as soon as it can run after. Until then it waits in Drafts.")
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surfaceRaised)
    }
}

private extension SendLaterKind {
    var icon: NimbraIcon {
        switch self {
        case .inAnHour: .clock
        case .thisEvening: .moon
        case .tomorrowMorning: .sun
        case .mondayMorning: .calendar
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .inAnHour: "In an hour"
        case .thisEvening: "This evening"
        case .tomorrowMorning: "Tomorrow morning"
        case .mondayMorning: "Monday morning"
        }
    }

    /// The time on the right: "10:41 AM", "Fri 8:00 AM", "Nov 30, 8:00 AM".
    func label(_ date: Date) -> String {
        switch self {
        case .inAnHour, .thisEvening: date.formatted(date: .omitted, time: .shortened)
        case .tomorrowMorning: date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        case .mondayMorning: date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
    }
}
