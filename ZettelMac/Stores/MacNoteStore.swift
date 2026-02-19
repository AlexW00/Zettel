//
//  MacNoteStore.swift
//  ZettelMac
//
//  macOS-native note persistence layer.
//  Manages file I/O, directory monitoring, and security-scoped bookmarks.
//

import Foundation
import AppKit
import ZettelKit

/// macOS-native note store — manages reading/writing .md files.
/// Shared singleton; individual windows manage their own note state.
@MainActor @Observable
public final class MacNoteStore {

    public static let shared = MacNoteStore()

    // MARK: - Published State

    /// All notes on disk (sorted by modifiedAt descending)
    public var allNotes: [Note] = []

    /// Current storage directory
    public var storageDirectory: URL

    /// Loading state
    public var isLoading: Bool = false

    // MARK: - Private

    private let storageDirectoryBookmarkKey = "macStorageDirectoryBookmark"
    private var refreshDebounceTask: Task<Void, Never>?
    private var activationObserver: (any NSObjectProtocol)?

    // MARK: - Init

    private init() {
        // Default to ~/Documents
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.storageDirectory = documentsURL

        // Restore saved directory
        if let restored = restoreStorageDirectory() {
            self.storageDirectory = restored
        }

        createStorageDirectoryIfNeeded()

        // Reload notes when app regains focus (catches external file changes)
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.loadAllNotes()
            }
        }
    }

    // MARK: - Public API

    /// Load all notes from the storage directory
    public func loadAllNotes() async {
        isLoading = true
        defer { isLoading = false }

        let didStartAccessing = storageDirectory.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                storageDirectory.stopAccessingSecurityScopedResource()
            }
        }

        let directory = storageDirectory
        let notes = await Task.detached { () -> [Note] in
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey], options: [.skipsHiddenFiles]) else {
                return []
            }

            return files.compactMap { url -> Note? in
                guard url.pathExtension == "md" else { return nil }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

                let title = url.deletingPathExtension().lastPathComponent
                let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
                let modifiedAt = resourceValues?.contentModificationDate ?? Date()
                let createdAt = resourceValues?.creationDate ?? modifiedAt

                return Note.fromSerializedContent(content, fallbackTitle: title, createdAt: createdAt, modifiedAt: modifiedAt)
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
        }.value

        self.allNotes = notes
    }

    /// Save a note to disk. Returns the final filename used.
    @discardableResult
    public func saveNote(_ note: Note, originalFilename: String? = nil) -> String? {
        let didStartAccessing = storageDirectory.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                storageDirectory.stopAccessingSecurityScopedResource()
            }
        }

        // Delete old file if renamed
        if let original = originalFilename, original != note.filename {
            let oldURL = storageDirectory.appendingPathComponent(original)
            try? FileManager.default.removeItem(at: oldURL)
        }

        // Determine the filename: reuse original if not renamed, otherwise generate unique
        let targetFilename: String
        if let original = originalFilename, original == note.filename {
            targetFilename = original
        } else {
            targetFilename = note.generateUniqueFilename(in: storageDirectory)
        }

        let fileURL = storageDirectory.appendingPathComponent(targetFilename)

        do {
            try note.serializedContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // Update allNotes cache
            if let index = allNotes.firstIndex(where: { $0.id == targetFilename || $0.id == (originalFilename ?? "") }) {
                var updated = note
                // Ensure the note's title matches the filename we used
                allNotes[index] = updated
            } else {
                // New note — add to front
                allNotes.insert(note, at: 0)
            }

            return targetFilename
        } catch {
            print("[MacNoteStore] Error saving note: \(error)")
            return nil
        }
    }

    /// Delete a note from disk
    public func deleteNote(_ note: Note) {
        let didStartAccessing = storageDirectory.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                storageDirectory.stopAccessingSecurityScopedResource()
            }
        }

        let fileURL = storageDirectory.appendingPathComponent(note.filename)
        try? FileManager.default.removeItem(at: fileURL)
        allNotes.removeAll { $0.id == note.id }
    }

    /// Load a single note from a file URL
    public func loadNoteFromFile(_ url: URL) -> Note? {
        guard url.pathExtension == "md" else { return nil }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let title = url.deletingPathExtension().lastPathComponent
        let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let modifiedAt = resourceValues?.contentModificationDate ?? Date()
        let createdAt = resourceValues?.creationDate ?? modifiedAt

        return Note.fromSerializedContent(content, fallbackTitle: title, createdAt: createdAt, modifiedAt: modifiedAt)
    }

    /// Update storage directory
    public func updateStorageDirectory(_ newDirectory: URL) {
        let didStartAccessing = newDirectory.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                newDirectory.stopAccessingSecurityScopedResource()
            }
        }

        saveStorageDirectoryBookmark(newDirectory)
        self.storageDirectory = newDirectory
        createStorageDirectoryIfNeeded()

        Task {
            await loadAllNotes()
        }
    }

    // MARK: - Storage Directory Persistence

    private func createStorageDirectoryIfNeeded() {
        let didStartAccessing = storageDirectory.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                storageDirectory.stopAccessingSecurityScopedResource()
            }
        }
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    private func saveStorageDirectoryBookmark(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: storageDirectoryBookmarkKey)
        } catch {
            print("[MacNoteStore] Error saving bookmark: \(error)")
        }
    }

    private func restoreStorageDirectory() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: storageDirectoryBookmarkKey) else {
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                saveStorageDirectoryBookmark(url)
            }

            _ = url.startAccessingSecurityScopedResource()
            return url
        } catch {
            print("[MacNoteStore] Error restoring bookmark: \(error)")
            return nil
        }
    }
}
