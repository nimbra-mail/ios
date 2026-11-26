import Foundation
import NimbraCore

/// Someone mail is from or to.
nonisolated struct Person: Hashable, Sendable {
    let name: String
    let email: String
    let tone: Tone

    init(name: String, email: String, tone: Tone? = nil) {
        self.name = name
        self.email = email
        self.tone = tone ?? .for(name.isEmpty ? email : name)
    }

    /// The engine's person: the address when there is no name.
    init(_ person: NimbraCore.Person) {
        self.init(name: person.name, email: person.address)
    }

    /// Up to two letters: the first of the first and last words ("Mira
    /// Kovač" is MK), or the first letter of a one-word name.
    var initials: String {
        let words = name.split(whereSeparator: \.isWhitespace)
        let letters = [words.first, words.count > 1 ? words.last : nil].compactMap { $0?.first }
        return letters.isEmpty ? String(email.prefix(1)).uppercased() : String(letters).uppercased()
    }

    /// The first name, for "Mira, Jonah and you".
    var firstName: String {
        name.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? (name.isEmpty ? email : name)
    }
}
