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

// MARK: - Notifications

extension Notification.Name {
    /// Posted when a note file changes on disk externally.
    /// `userInfo` keys: `"filename"` (String), `"content"` (String),
    /// `"title"` (String), `"modifiedAt"` (Date), `"createdAt"` (Date).
    static let noteFileDidChangeOnDisk = Notification.Name("noteFileDidChangeOnDisk")

    /// Posted when the storage directory is changed (e.g. from Settings).
    /// Windows should flush pending saves and reset to a new note.
    static let storageDirectoryDidChange = Notification.Name("storageDirectoryDidChange")
}

/// macOS-native note store — manages reading/writing .md files.
/// Shared singleton; individual windows manage their own note state.
@MainActor @Observable
public final class MacNoteStore: NSObject, NSFilePresenter {

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
    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let repository: NoteFileRepository
    private let monitorsFileSystem: Bool
    private var refreshDebounceTask: Task<Void, Never>?
    private var activationObserver: (any NSObjectProtocol)?

    // MARK: - NSFilePresenter Support

    /// The directory being monitored for file system changes.
    nonisolated(unsafe) private var _presentedItemURL: URL?
    /// Operation queue used by the file presenter system.
    public nonisolated let presentedItemOperationQueue = OperationQueue()
    private var fileCoordinator: NSFileCoordinator?

    /// Filenames recently written/deleted by this process, keyed by timestamp.
    /// Used to suppress echo notifications from NSFilePresenter.
    private var recentlyOwnedFiles: [String: Date] = [:]
    private let ownedFileFeedbackWindow: TimeInterval = 3.0

    nonisolated public var presentedItemURL: URL? {
        return _presentedItemURL
    }

    // MARK: - Init

    init(
        storageDirectory: URL? = nil,
        userDefaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        repository: NoteFileRepository = NoteFileRepository(),
        shouldStartMonitoringFileSystem: Bool = true,
        observeActivation: Bool = true
    ) {
        // Default to ~/Documents/Zettel
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.storageDirectory = storageDirectory ?? documentsURL.appendingPathComponent("Zettel", isDirectory: true)
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        self.repository = repository
        self.monitorsFileSystem = shouldStartMonitoringFileSystem

        super.init()

        // Restore saved directory
        if storageDirectory == nil, let restored = restoreStorageDirectory() {
            self.storageDirectory = restored
        }

        self._presentedItemURL = self.storageDirectory
        createStorageDirectoryIfNeeded()
        if shouldStartMonitoringFileSystem {
            startMonitoringFileSystem()
        }

        // Reload notes when app regains focus (catches external file changes)
        if observeActivation {
            activationObserver = notificationCenter.addObserver(
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
    }

    // MARK: - Public API

    /// Load all notes from the storage directory
    public func loadAllNotes() async {
        // Only show loading spinner on initial load, not on subsequent refreshes
        let isInitialLoad = allNotes.isEmpty
        if isInitialLoad { isLoading = true }
        defer { if isInitialLoad { isLoading = false } }

        let didStartAccessing = storageDirectory.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                storageDirectory.stopAccessingSecurityScopedResource()
            }
        }

        let directory = storageDirectory
        let repository = self.repository
        let notes = await Task.detached { () -> [Note] in
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [
                    .contentModificationDateKey,
                    .creationDateKey,
                    .ubiquitousItemDownloadingStatusKey
                ],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            var result: [Note] = []

            for url in files where url.pathExtension == "md" {
                let title = url.deletingPathExtension().lastPathComponent
                let resourceValues = try? url.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .creationDateKey,
                    .ubiquitousItemDownloadingStatusKey
                ])
                let modifiedAt = resourceValues?.contentModificationDate ?? Date()
                let createdAt = resourceValues?.creationDate ?? modifiedAt

                // Check if the file is downloaded or just a cloud stub
                let isDownloaded: Bool
                if let status = resourceValues?.ubiquitousItemDownloadingStatus {
                    isDownloaded = (status == .current || status == .downloaded)
                } else {
                    // No ubiquity status means it's a plain local file
                    isDownloaded = true
                }

                if isDownloaded {
                    if let note = repository.loadNote(from: url) {
                        result.append(note)
                    }
                } else {
                    // Cloud stub — create placeholder and queue background download
                    var placeholder = Note(title: title, content: "")
                    placeholder.createdAt = createdAt
                    placeholder.modifiedAt = modifiedAt
                    placeholder.isCloudStub = true
                    placeholder.cloudURL = url
                    placeholder.isDownloading = true
                    result.append(placeholder)
                }
            }

            return result.sorted { $0.modifiedAt > $1.modifiedAt }
        }.value

        self.allNotes = notes

        // Kick off background downloads for any cloud stubs
        for note in notes where note.isCloudStub {
            Task.detached { [weak self] in
                await self?.downloadCloudFileInBackground(fileURL: note.cloudURL!, noteId: note.id)
            }
        }
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

        do {
            let saveResult = try repository.save(note, in: storageDirectory, originalFilename: originalFilename)

            // Track this save to suppress echo from file monitor
            recentlyOwnedFiles[saveResult.filename] = Date()
            if let originalFilename, originalFilename != saveResult.filename {
                recentlyOwnedFiles[originalFilename] = Date()
            }

            // Update allNotes cache
            if let index = allNotes.firstIndex(where: { $0.id == (originalFilename ?? note.id) || $0.id == saveResult.filename }) {
                allNotes[index] = Note.fromSerializedContent(
                    note.serializedContent,
                    fallbackTitle: saveResult.fileURL.deletingPathExtension().lastPathComponent,
                    createdAt: allNotes[index].createdAt,
                    modifiedAt: note.modifiedAt
                )
            } else {
                // New note — add to front
                let persistedNote = Note.fromSerializedContent(
                    note.serializedContent,
                    fallbackTitle: saveResult.fileURL.deletingPathExtension().lastPathComponent,
                    createdAt: note.createdAt,
                    modifiedAt: note.modifiedAt
                )
                allNotes.insert(persistedNote, at: 0)
            }

            allNotes.sort { $0.modifiedAt > $1.modifiedAt }

            return saveResult.filename
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

        recentlyOwnedFiles[note.filename] = Date()
        try? repository.delete(note, from: storageDirectory)
        allNotes.removeAll { $0.id == note.id }
    }

    /// Load a single note from a file URL
    public func loadNoteFromFile(_ url: URL) -> Note? {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return repository.loadNote(from: url)
    }

    // MARK: - Cloud File Support

    /// Checks if a file is downloaded locally (not just a cloud stub)
    nonisolated private func isFileDownloaded(_ url: URL) -> Bool {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            guard let status = resourceValues.ubiquitousItemDownloadingStatus else {
                return true // No ubiquity info → local file
            }
            return status == .current || status == .downloaded
        } catch {
            return true // Assume available on error
        }
    }

    /// Downloads a cloud-offloaded file in the background and updates `allNotes` when done.
    nonisolated private func downloadCloudFileInBackground(fileURL: URL, noteId: String) async {
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)

            // Poll until downloaded or timeout
            let timeout: TimeInterval = 60
            let start = Date()
            while Date().timeIntervalSince(start) < timeout {
                if isFileDownloaded(fileURL) { break }
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }

            guard isFileDownloaded(fileURL) else {
                await markDownloadFinished(noteId: noteId, success: false)
                return
            }

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let title = fileURL.deletingPathExtension().lastPathComponent
            let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
            let modifiedAt = resourceValues?.contentModificationDate ?? Date()
            let createdAt = resourceValues?.creationDate ?? modifiedAt

            var updatedNote = Note.fromSerializedContent(content, fallbackTitle: title, createdAt: createdAt, modifiedAt: modifiedAt)
            updatedNote.isCloudStub = false
            updatedNote.isDownloading = false
            updatedNote.cloudURL = nil

            await MainActor.run {
                if let index = MacNoteStore.shared.allNotes.firstIndex(where: { $0.id == noteId }) {
                    MacNoteStore.shared.allNotes[index] = updatedNote
                }
            }
        } catch {
            print("[MacNoteStore] Background download failed for \(fileURL): \(error)")
            await markDownloadFinished(noteId: noteId, success: false)
        }
    }

    /// Downloads a cloud file synchronously (with polling) for on-demand access.
    /// Returns the downloaded `Note`, or throws on failure.
    public func downloadCloudFile(for note: Note) async throws -> Note {
        guard note.isCloudStub, let cloudURL = note.cloudURL else {
            throw NSError(domain: "MacNoteStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Note is not a cloud stub"])
        }

        try FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)

        let timeout: TimeInterval = 30
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if isFileDownloaded(cloudURL) { break }
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        guard isFileDownloaded(cloudURL) else {
            throw NSError(domain: "MacNoteStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Download timed out"])
        }

        let content = try String(contentsOf: cloudURL, encoding: .utf8)
        let title = cloudURL.deletingPathExtension().lastPathComponent
        let resourceValues = try? cloudURL.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let modifiedAt = resourceValues?.contentModificationDate ?? Date()
        let createdAt = resourceValues?.creationDate ?? modifiedAt

        var downloaded = Note.fromSerializedContent(content, fallbackTitle: title, createdAt: createdAt, modifiedAt: modifiedAt)
        downloaded.isCloudStub = false
        downloaded.isDownloading = false
        downloaded.cloudURL = nil

        // Update allNotes cache
        if let index = allNotes.firstIndex(where: { $0.id == note.id }) {
            allNotes[index] = downloaded
        }

        return downloaded
    }

    /// Helper to clear downloading flag when a background download ends.
    private func markDownloadFinished(noteId: String, success: Bool) async {
        await MainActor.run {
            if let index = MacNoteStore.shared.allNotes.firstIndex(where: { $0.id == noteId }) {
                MacNoteStore.shared.allNotes[index].isDownloading = false
            }
        }
    }

    /// Update storage directory
    public func updateStorageDirectory(_ newDirectory: URL) {
        if monitorsFileSystem {
            stopMonitoringFileSystem()
        }

        let didStartAccessing = newDirectory.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                newDirectory.stopAccessingSecurityScopedResource()
            }
        }

        saveStorageDirectoryBookmark(newDirectory)
        self.storageDirectory = newDirectory
        self._presentedItemURL = newDirectory
        createStorageDirectoryIfNeeded()
        if monitorsFileSystem {
            startMonitoringFileSystem()
        }

        // Notify all windows so they can flush saves and reset
        notificationCenter.post(name: .storageDirectoryDidChange, object: nil)

        Task {
            await loadAllNotes()
        }
    }

    // MARK: - File System Monitoring

    private func startMonitoringFileSystem() {
        fileCoordinator = NSFileCoordinator(filePresenter: self)
        NSFileCoordinator.addFilePresenter(self)
    }

    private func stopMonitoringFileSystem() {
        NSFileCoordinator.removeFilePresenter(self)
        fileCoordinator = nil
    }

    /// Debounced refresh of allNotes after file system events.
    private func scheduleDebouncedRefresh() {
        refreshDebounceTask?.cancel()
        refreshDebounceTask = Task {
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            // Purge stale owned-file entries
            let cutoff = Date().addingTimeInterval(-ownedFileFeedbackWindow)
            recentlyOwnedFiles = recentlyOwnedFiles.filter { $0.value > cutoff }
            await self.loadAllNotes()
        }
    }

    // MARK: - NSFilePresenter Callbacks

    nonisolated public func presentedSubitemDidChange(at url: URL) {
        guard url.pathExtension == "md" else { return }
        let filename = url.lastPathComponent
        Task { @MainActor in
            // Skip if this change was caused by our own write/delete
            if let saveTime = self.recentlyOwnedFiles[filename],
               Date().timeIntervalSince(saveTime) < self.ownedFileFeedbackWindow {
                return
            }
            self.scheduleDebouncedRefresh()
            self.notifyActiveNoteChanged(filename: filename, url: url)
        }
    }

    nonisolated public func presentedItemDidChange() {
        Task { @MainActor in
            self.scheduleDebouncedRefresh()
        }
    }

    nonisolated public func presentedSubitemDidAppear(at url: URL) {
        Task { @MainActor in
            self.scheduleDebouncedRefresh()
        }
    }

    nonisolated public func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
        Task { @MainActor in
            self.scheduleDebouncedRefresh()
        }
    }

    /// Reads the changed file and posts a notification so windows editing
    /// that file can update their content.
    private func notifyActiveNoteChanged(filename: String, url: URL) {
        Task.detached {
            // Only notify if the file still exists and is readable
            guard FileManager.default.fileExists(atPath: url.path),
                  let content = try? String(contentsOf: url, encoding: .utf8) else {
                return
            }
            let resourceValues = try? url.resourceValues(forKeys: [
                .contentModificationDateKey, .creationDateKey
            ])
            let modifiedAt = resourceValues?.contentModificationDate ?? Date()
            let createdAt = resourceValues?.creationDate ?? modifiedAt
            let title = url.deletingPathExtension().lastPathComponent

            await MainActor.run {
                self.notificationCenter.post(
                    name: .noteFileDidChangeOnDisk,
                    object: nil,
                    userInfo: [
                        "filename": filename,
                        "content": content,
                        "title": title,
                        "modifiedAt": modifiedAt,
                        "createdAt": createdAt
                    ]
                )
            }
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
        try? repository.createDirectoryIfNeeded(at: storageDirectory)
    }

    private func saveStorageDirectoryBookmark(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            userDefaults.set(bookmark, forKey: storageDirectoryBookmarkKey)
        } catch {
            print("[MacNoteStore] Error saving bookmark: \(error)")
        }
    }

    private func restoreStorageDirectory() -> URL? {
        guard let bookmark = userDefaults.data(forKey: storageDirectoryBookmarkKey) else {
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
