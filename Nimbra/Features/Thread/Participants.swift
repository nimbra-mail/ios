import SwiftUI

/// Overlapping faces and "Mira, Jonah and you · 3 messages".
struct Participants: View {
    let people: [Person]

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: -5) {
                ForEach(people.prefix(3), id: \.email) { person in
                    AvatarView(person: person, size: 24)
                        .padding(2)
                        .background(Color.bgList, in: .circle)
                }
            }
            .padding(-2)
            Text(verbatim: names)
                .nimbraText(.footnote)
                .foregroundStyle(Color.textTertiary)
        }
    }

    /// Others by first name, the signed-in person as "you".
    private var names: String {
        let others = people.filter { $0.email != SampleData.me.email }.map(\.firstName)
        let you = String(localized: "you")
        let all = people.contains { $0.email == SampleData.me.email } ? others + [you] : others
        return all.formatted(.list(type: .and))
    }
}
