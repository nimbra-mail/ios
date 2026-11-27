import SwiftUI

/// Who to send to, for what is typed (13 · Compose · Suggestions): the best first,
/// highlighted, the typed part of each name in Medium.
struct SuggestionList: View {
    let people: [Person]
    let typed: String
    let pick: (Person) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(people.enumerated()), id: \.element.email) { index, person in
                Button {
                    pick(person)
                } label: {
                    PersonRow(
                        person: person,
                        title: .matching(person.name.isEmpty ? person.email : person.name, typed: typed),
                        subtitle: person.email,
                        divider: true
                    )
                    .padding(.horizontal, 20)
                    .background(index == 0 ? Color.surfaceSelected : .clear)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Suggestions"))
    }
}
