import NimbraCore
import SwiftUI

/// Preferences as bindings for Settings' switches and menus: shown from the model, kept
/// through the engine (`setPreference`).
extension AppModel {
    /// A preference as a binding: shown from the model, kept through the engine.
    func preference<Value: Equatable>(_ keyPath: WritableKeyPath<Preferences, Value>) -> Binding<Value> {
        Binding {
            self.preferences[keyPath: keyPath]
        } set: { value in
            Task { await self.setPreference(keyPath, value) }
        }
    }

    /// A preference stored as a number, picked as a choice.
    func preference<Choice>(
        _ keyPath: WritableKeyPath<Preferences, UInt32>, _ choice: @escaping (UInt32) -> Choice, _ seconds: KeyPath<Choice, UInt32>
    ) -> Binding<Choice> {
        Binding {
            choice(self.preferences[keyPath: keyPath])
        } set: { value in
            Task { await self.setPreference(keyPath, value[keyPath: seconds]) }
        }
    }
}
