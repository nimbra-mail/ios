import Foundation

/// A signed-in mailbox.
nonisolated struct Account: Identifiable, Hashable {
    let id: UUID
    /// What the account is called ("Riangle", "Personal").
    let name: String
    /// Who it belongs to, for the avatar.
    let owner: String
    let email: String
    let tone: Tone

    init(name: String, owner: String, email: String, tone: Tone) {
        self.id = UUID()
        self.name = name
        self.owner = owner
        self.email = email
        self.tone = tone
    }

    var person: Person { Person(name: owner, email: email, tone: tone) }
}
