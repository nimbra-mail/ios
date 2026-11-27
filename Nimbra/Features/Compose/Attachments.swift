import Foundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Files picked for a message, read off the main actor: photos (HEIC as JPEG, so anyone
/// can open them) and files from Files.
nonisolated enum Attachments {
    static func photos(_ items: [PhotosPickerItem]) async -> [Composer.File] {
        var files: [Composer.File] = []
        for (index, item) in items.enumerated() {
            guard var data = try? await item.loadTransferable(type: Data.self) else { continue }
            var type = item.supportedContentTypes.first(where: { $0.conforms(to: .image) }) ?? .jpeg
            if type.conforms(to: .heic) || type.conforms(to: .heif) || type.preferredMIMEType == nil {
                guard let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.9) else { continue }
                data = jpeg
                type = .jpeg
            }
            let ext = type.preferredFilenameExtension ?? "jpg"
            let name = items.count == 1
                ? String(localized: "Photo") + ".\(ext)"
                : String(localized: "Photo") + "-\(index + 1).\(ext)"
            files.append(Composer.File(name: name, mime: type.preferredMIMEType ?? "image/jpeg", bytes: data))
        }
        return files
    }

    static func files(_ urls: [URL]) async -> [Composer.File] {
        await Task.detached(priority: .userInitiated) {
            urls.compactMap { url -> Composer.File? in
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
                let type = UTType(filenameExtension: url.pathExtension)
                return Composer.File(
                    name: url.lastPathComponent,
                    mime: type?.preferredMIMEType ?? "application/octet-stream",
                    bytes: data
                )
            }
        }.value
    }
}
