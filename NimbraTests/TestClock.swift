import Foundation
import Synchronization
@testable import Nimbra

/// A clock the test moves: `sleep` waits until `advance` passes its time (or the task is
/// cancelled), so an undo time or a draft pause takes no real time.
nonisolated final class TestClock: Sendable {
    private struct Sleeper {
        let id: UUID
        let until: Date
        let wake: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now: Date
        var sleepers: [Sleeper] = []
    }

    private let state: Mutex<State>

    init(now: Date = Date(milliseconds: 1_800_000_000_000)) {
        state = Mutex(State(now: now))
    }

    var now: Date { state.withLock { $0.now } }

    var clock: AppClock {
        AppClock(now: { [self] in now }, sleep: { [self] duration in try await sleep(duration) })
    }

    /// Sleepers waiting now.
    var sleeping: Int { state.withLock { $0.sleepers.count } }

    func advance(by duration: Duration) {
        let woken = state.withLock { state -> [Sleeper] in
            state.now += TimeInterval(duration.components.seconds) + TimeInterval(duration.components.attoseconds) / 1e18
            let due = state.sleepers.filter { $0.until <= state.now }
            state.sleepers.removeAll { $0.until <= state.now }
            return due
        }
        woken.forEach { $0.wake.resume() }
    }

    private func sleep(_ duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (wake: CheckedContinuation<Void, any Error>) in
                let cancelled = state.withLock { state -> Bool in
                    if Task.isCancelled { return true }
                    let until = state.now + TimeInterval(duration.components.seconds) + TimeInterval(duration.components.attoseconds) / 1e18
                    state.sleepers.append(Sleeper(id: id, until: until, wake: wake))
                    return false
                }
                if cancelled { wake.resume(throwing: CancellationError()) }
            }
        } onCancel: {
            let sleeper = state.withLock { state -> Sleeper? in
                guard let index = state.sleepers.firstIndex(where: { $0.id == id }) else { return nil }
                return state.sleepers.remove(at: index)
            }
            sleeper?.wake.resume(throwing: CancellationError())
        }
    }
}

/// Lets the app's tasks run until `condition` holds (engine calls run on their own threads).
@MainActor
func eventually(_ condition: () -> Bool, timeout: Duration = .seconds(3)) async -> Bool {
    let end = ContinuousClock.now + timeout
    while !condition() {
        if ContinuousClock.now > end { return false }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return true
}
