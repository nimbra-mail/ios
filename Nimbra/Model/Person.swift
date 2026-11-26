import Foundation

/// Someone mail is from or to.
nonisolated struct Person: Hashable {
    let name: String
    let email: String
    let tone: Tone

    init(name: String, email: String, tone: Tone? = nil) {
        self.name = name
        self.email = email
        self.tone = tone ?? .for(name)
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
        name.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? name
    }
}
