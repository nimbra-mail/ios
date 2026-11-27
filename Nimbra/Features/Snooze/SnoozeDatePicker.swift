import NimbraCore
import SwiftUI

/// 05 · Snooze's "Pick a date and time": a day in the calendar, and a time typed as on the
/// Mac ("4:30 PM", "16:30", "430p", "noon"), read by the engine. The day starts on today
/// when the time is still ahead, else tomorrow.
struct SnoozeDatePicker: View {
    let snooze: (Date) -> Void
    /// The time last picked, in minutes after midnight (9:00 AM at first, as on the Mac).
    @AppStorage("Snooze.Time") private var minutes = 9 * 60
    @State private var day = Date.now
    @State private var typed = ""
    @FocusState private var typing: Bool

    private var time: TimeOfDay {
        TimeOfDay(hour: UInt32(minutes / 60), minute: UInt32(minutes % 60))
    }

    /// When the day and time make, if it is still ahead.
    private var chosen: Date? {
        SnoozePick.date(day: day, time: time)
    }

    /// What is typed is not a time.
    private var typedIsBad: Bool {
        !typed.trimmingCharacters(in: .whitespaces).isEmpty && SnoozePick.time(typed) == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("Day", selection: $day, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Color.accentColor)
                .padding(.horizontal, 12)

            HStack(spacing: 12) {
                Icon(.clock).foregroundStyle(Color.textSecondary)
                Text("Time")
                    .nimbraText(.body)
                    .foregroundStyle(Color.textPrimary)
                Spacer(minLength: 8)
                TextField("Time", text: $typed, prompt: Text(verbatim: SnoozePick.text(time)))
                    .nimbraText(.body)
                    .foregroundStyle(typedIsBad ? Color.accentRose : Color.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($typing)
                    .accessibilityHint(Text("A time such as 4:30 PM, 16:30 or noon"))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .overlay(alignment: .top) { Divider().overlay(Color.borderSubtle) }

            VStack(spacing: 8) {
                if typedIsBad {
                    note("That is not a time.")
                } else if chosen == nil {
                    note("That time has passed. Pick a later one.")
                }
                PrimaryButton("Snooze") {
                    if let chosen { snooze(chosen) }
                }
                .disabled(chosen == nil || typedIsBad)
            }
            .padding(16)
        }
        .onChange(of: typed) { _, text in
            if let parsed = SnoozePick.time(text) {
                minutes = Int(parsed.hour) * 60 + Int(parsed.minute)
            }
        }
        .onAppear {
            day = SnoozePick.firstOpenDay(time: time, now: .now)
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .nimbraText(.footnote)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
