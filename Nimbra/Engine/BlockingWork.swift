import Foundation

/// Where the engine's blocking calls run: threads of their own, off the main actor and off
/// Swift's cooperative pool.
///
/// Every `Engine` method blocks, some for as long as a server takes to answer (a minute at
/// most) and a change watch for its whole interval. Swift concurrency's pool has one thread
/// per core and expects work on it never to block, so `Task.detached` would let a few slow
/// servers stall every other task in the app. A serial executor would keep a quick read of
/// the store waiting behind a slow refresh. The engine guards its own state (it is
/// `Sendable`), so its calls run side by side here, each on a thread that may block, and
/// hand their answer back to the awaiting task.
nonisolated enum BlockingWork {
    private static let queue = DispatchQueue(
        label: "com.riangle.nimbra.engine",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// Runs `work` on an engine thread and returns its result. It runs to the end even when
    /// the awaiting task is cancelled: an engine call cannot be stopped halfway.
    static func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try work() })
            }
        }
    }
}
