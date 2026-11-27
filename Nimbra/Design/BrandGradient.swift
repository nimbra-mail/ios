import SwiftUI

extension ShapeStyle where Self == LinearGradient {
    /// The desktop's primary fill (Send, Compose): violet into rose.
    static var brand: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.592, green: 0.533, blue: 1), Color(red: 1, green: 0.533, blue: 0.741)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// The kit's primary Button (iOS/Button, Kind=Primary): violet #8B7CFF, orchid #C06BE0
    /// at 55%, rose #FF7AB6.
    static var brandButton: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.545, green: 0.486, blue: 1), location: 0),
                .init(color: Color(red: 0.753, green: 0.420, blue: 0.878), location: 0.55),
                .init(color: Color(red: 1, green: 0.478, blue: 0.714), location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
