import Foundation

/// Attachments written for Quick Look and the share sheet: one folder per thread under the
/// app's temporary folder, readable by this app only (0700 and 0600), encrypted while the
/// iPhone is locked (complete file protection), and removed when the thread is left. Mail
/// stays on the device: these files are never backed up or kept.
nonisolated enum AttachmentFiles {
    /// Where every thread's folder lives.
    static var root: URL {
        FileManager.default.temporaryDirectory.appending(path: "Attachments", directoryHint: .isDirectory)
    }

    /// Writes `data` as `name` in the thread's folder, in a folder of its own (two files
    /// with the same name never meet), and returns the file.
    static func write(_ data: Data, named name: String, for thread: MailThread.ID) throws -> URL {
        _ = clearedAtLaunch
        let manager = FileManager.default
        let folder = self.folder(for: thread).appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = folder.appending(path: safeName(name), directoryHint: .notDirectory)
        try data.write(to: file, options: [.completeFileProtection, .withoutOverwriting])
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path(percentEncoded: false))
        return file
    }

    /// Removes the files written for a thread.
    static func remove(for thread: MailThread.ID) {
        try? FileManager.default.removeItem(at: folder(for: thread))
    }

    /// Removes every file written.
    static func removeAll() {
        try? FileManager.default.removeItem(at: root)
    }

    /// What an earlier launch left (it quit before the thread was left), removed before the
    /// first file of this one.
    private static let clearedAtLaunch: Void = removeAll()

    /// A thread's folder: named by a digest of its ids, never by them (they are the
    /// provider's, and may hold anything).
    static func folder(for thread: MailThread.ID) -> URL {
        let key = "\(thread.account)\u{0}\(thread.thread)".utf8.reduce(into: UInt64(14_695_981_039_346_656_037)) { hash, byte in
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return root.appending(path: String(key, radix: 16), directoryHint: .isDirectory)
    }

    /// The engine already makes names safe; this keeps a file in its folder whatever it is
    /// given: the last path component, no leading dots, never empty.
    static func safeName(_ name: String) -> String {
        let last = name.split(whereSeparator: { $0 == "/" || $0 == "\\" || $0 == ":" }).last.map(String.init) ?? ""
        let trimmed = last.drop { $0 == "." || $0.isWhitespace }.filter { !$0.isNewline && $0 != "\u{0}" }
        return trimmed.isEmpty ? String(localized: "Attachment") : String(trimmed.prefix(200))
    }
}
