import Foundation
import NimbraCore

/// Owns the mail engine for the app's lifetime and runs its calls.
///
/// Every engine call goes through `call`, which runs it on an engine thread
/// (`BlockingWork`), never the main actor, and turns what it throws into a `MailError`.
nonisolated final class EngineHost: Sendable {
    let engine: any MailEngine
    /// The OAuth clients this build was made with.
    let oauth: OAuthConfig

    init(engine: any MailEngine, oauth: OAuthConfig) {
        self.engine = engine
        self.oauth = oauth
    }

    /// The real engine over the app's folders and Keychain, with the system's resolver
    /// for discovery's MX lookups. Once per process: the engine keeps its folders for the
    /// process's life. Disk and Keychain, so call it off the main actor (`start`).
    static func live(oauth: OAuthConfig = .bundled) throws(MailError) -> EngineHost {
        do {
            let folders = try EngineFolders.app()
            let engine = try Engine(
                config: oauth.engineConfig,
                dataDir: folders.data.path(percentEncoded: false),
                cacheDir: folders.cache.path(percentEncoded: false),
                secrets: KeychainSecretStore()
            )
            try useDnsResolver(resolver: SystemDNSResolver())
            return EngineHost(engine: engine, oauth: oauth)
        } catch {
            throw MailError(error)
        }
    }

    /// `live`, on an engine thread.
    static func start(oauth: OAuthConfig = .bundled) async throws(MailError) -> EngineHost {
        do {
            return try await BlockingWork.run { try live(oauth: oauth) }
        } catch {
            throw MailError(error)
        }
    }

    /// Runs one or more engine calls on an engine thread.
    func call<T: Sendable>(_ work: @escaping @Sendable (any MailEngine) throws -> T) async throws(MailError) -> T {
        let engine = engine
        do {
            return try await BlockingWork.run { try work(engine) }
        } catch {
            throw MailError(error)
        }
    }

    /// Writes what waits to be written: when the app goes to the background.
    @discardableResult
    func flush() async -> Bool {
        (try? await call { $0.flush() }) ?? false
    }
}
