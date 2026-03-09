import Foundation

/// Foundation-only note file persistence used by app stores and tests.
public struct NoteFileRepository: Sendable {
    public struct SaveResult: Equatable, Sendable {
        public let filename: String
        public let fileURL: URL

        public init(filename: String, fileURL: URL) {
            self.filename = filename
            self.fileURL = fileURL
        }
    }

    public init() {}

    public func createDirectoryIfNeeded(at directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func loadNotes(in directory: URL) throws -> [Note] {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        return try fileURLs
            .filter { $0.pathExtension == "md" }
            .map(loadRequiredNote(from:))
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    public func loadNote(from url: URL) -> Note? {
        try? loadRequiredNote(from: url)
    }

    @discardableResult
    public func save(_ note: Note, in directory: URL, originalFilename: String? = nil) throws -> SaveResult {
        try createDirectoryIfNeeded(at: directory)

        let targetFilename: String
        if let originalFilename, originalFilename == note.filename {
            targetFilename = originalFilename
        } else {
            targetFilename = note.generateUniqueFilename(in: directory)
        }

        let targetURL = directory.appendingPathComponent(targetFilename)
        try note.serializedContent.write(to: targetURL, atomically: true, encoding: .utf8)

        if let originalFilename, originalFilename != targetFilename {
            let originalURL = directory.appendingPathComponent(originalFilename)
            if FileManager.default.fileExists(atPath: originalURL.path) {
                try FileManager.default.removeItem(at: originalURL)
            }
        }

        return SaveResult(filename: targetFilename, fileURL: targetURL)
    }

    public func delete(_ note: Note, from directory: URL) throws {
        let fileURL = directory.appendingPathComponent(note.filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: fileURL)
    }

    private func loadRequiredNote(from url: URL) throws -> Note {
        guard url.pathExtension == "md" else {
            throw NoteError.fileSystemError("Unsupported file type: \(url.pathExtension)")
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let title = url.deletingPathExtension().lastPathComponent
        let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let modifiedAt = resourceValues?.contentModificationDate ?? Date()
        let createdAt = resourceValues?.creationDate ?? modifiedAt

        return Note.fromSerializedContent(
            content,
            fallbackTitle: title,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }
}
