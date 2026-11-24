import AVFoundation
import CoreTransferable
import Foundation
import NoGymKit
import UniformTypeIdentifiers

/// The app's own copies of workout videos, in Documents/Videos.
/// A sequence stores only the file name; deleting the original from Photos doesn't break it.
enum VideoLibrary {
    static let folder = URL.documentsDirectory.appending(path: "Videos", directoryHint: .isDirectory)

    static func url(for fileName: String) -> URL {
        folder.appending(path: fileName)
    }

    static func url(for video: WorkoutVideo) -> URL {
        url(for: video.fileName)
    }

    enum ImportError: LocalizedError {
        case unreadable

        var errorDescription: String? { "That video can't be played." }
    }

    /// Copies a file into the library under a new name and returns its URL.
    static func copyIn(_ source: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension.lowercased()
        let destination = url(for: "\(UUID().uuidString).\(ext)")
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    /// Reads a copied file's length and wraps it as a video with no segments yet.
    /// Deletes the copy when it isn't a playable video.
    static func makeVideo(fromCopyAt fileURL: URL) async throws -> WorkoutVideo {
        let duration = try? await AVURLAsset(url: fileURL).load(.duration).seconds
        guard let duration, duration.isFinite, duration > 0 else {
            try? FileManager.default.removeItem(at: fileURL)
            throw ImportError.unreadable
        }
        return WorkoutVideo(fileName: fileURL.lastPathComponent, duration: duration)
    }

    /// Copies a file picked in Files, which needs security-scoped access.
    static func importFile(_ source: URL) async throws -> WorkoutVideo {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        return try await makeVideo(fromCopyAt: copyIn(source))
    }

    /// Deletes every video no saved sequence uses: replaced, removed, or picked and then cancelled.
    static func removeUnused(keeping fileNames: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where !fileNames.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

/// A video picked in Photos, already copied into the library.
/// The picker's file is temporary, so it's copied while the picker still holds it.
struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            PickedVideo(url: try VideoLibrary.copyIn(received.file))
        }
    }
}
