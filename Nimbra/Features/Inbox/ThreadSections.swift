import SwiftUI

/// Threads under TODAY and EARLIER.
struct ThreadSections: View {
    let threads: [MailThread]

    var body: some View {
        let today = threads.filter { Calendar.current.isDateInToday($0.date) }
        let earlier = threads.filter { !Calendar.current.isDateInToday($0.date) }
        LazyVStack(alignment: .leading, spacing: 0) {
            section("TODAY", today)
            section("EARLIER", earlier)
        }
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, _ threads: [MailThread]) -> some View {
        if !threads.isEmpty {
            Text(title)
                .nimbraText(.overline)
                .foregroundStyle(Color.textFaint)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)
            ForEach(threads) { thread in
                NavigationLink(value: thread.id) {
                    ThreadRow(thread: thread)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
