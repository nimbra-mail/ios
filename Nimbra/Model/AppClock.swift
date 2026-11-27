import Foundation

/// The time and a way to wait for it. The system's in the app; a test's to step through
/// an undo time without waiting for it.
nonisolated struct AppClock: Sendable {
    var now: @Sendable () -> Date
    var sleep: @Sendable (Duration) async throws -> Void

    static let system = AppClock(now: { .now }, sleep: { try await Task.sleep(for: $0) })
}
