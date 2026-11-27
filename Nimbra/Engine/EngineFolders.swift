import Foundation

/// The engine's two folders, inside the app's sandbox: `Application Support/Nimbra` for
/// the settings and each account's encrypted store, `Caches/Nimbra` for what can be
/// downloaded again.
nonisolated struct EngineFolders: Sendable, Equatable {
    let data: URL
    let cache: URL

    /// The app's own folders, made ready for the engine.
    static func app(fileManager: FileManager = .default) throws -> EngineFolders {
        let folders = EngineFolders(
            data: URL.applicationSupportDirectory.appending(path: "Nimbra", directoryHint: .isDirectory),
            cache: URL.cachesDirectory.appending(path: "Nimbra", directoryHint: .isDirectory)
        )
        try folders.prepare(fileManager: fileManager)
        return folders
    }

    /// Makes both folders. Mail data is readable from the first unlock after a restart
    /// until the next restart, so background refresh can open it while the iPhone is
    /// locked (files made inside take the folder's protection), and it stays out of
    /// iCloud and computer backups: it is on the server already, and the store's key is in
    /// a Keychain item that never leaves this device, so a backup of it could not be read.
    func prepare(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: data, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cache, withIntermediateDirectories: true)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: data.path(percentEncoded: false)
        )
        var data = data
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try data.setResourceValues(values)
    }
}
