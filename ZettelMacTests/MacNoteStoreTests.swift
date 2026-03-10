import Foundation
import Testing
import ZettelKit
@testable import Zettel

@MainActor
struct MacNoteStoreTests {
    @Test
    func saveNoteWritesFileAndUpdatesInMemoryCollection() throws {
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let store = MacNoteStore(
            storageDirectory: tempDirectory.url,
            userDefaults: makeIsolatedDefaults(),
            notificationCenter: NotificationCenter(),
            shouldStartMonitoringFileSystem: false,
            observeActivation: false
        )
        let note = Note(title: "Mac Save", content: "Body")

        let filename = store.saveNote(note)

        #expect(filename == "Mac Save.md")
        #expect(store.allNotes.count == 1)
        #expect(store.allNotes.first?.title == "Mac Save")
        #expect(FileManager.default.fileExists(atPath: tempDirectory.url.appendingPathComponent("Mac Save.md").path))
    }

    @Test
    func deleteNoteRemovesCachedNoteAndFile() throws {
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let store = MacNoteStore(
            storageDirectory: tempDirectory.url,
            userDefaults: makeIsolatedDefaults(),
            notificationCenter: NotificationCenter(),
            shouldStartMonitoringFileSystem: false,
            observeActivation: false
        )
        let note = Note(title: "Delete Mac", content: "")
        _ = store.saveNote(note)

        store.deleteNote(store.allNotes[0])

        #expect(store.allNotes.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: tempDirectory.url.appendingPathComponent("Delete Mac.md").path))
    }

    @Test
    func updateStorageDirectoryPostsNotificationAndReloadsNotes() async throws {
        let sourceDirectory = try TemporaryDirectory()
        let targetDirectory = try TemporaryDirectory()
        defer {
            sourceDirectory.cleanup()
            targetDirectory.cleanup()
        }

        let noteURL = targetDirectory.url.appendingPathComponent("Loaded.md")
        try "Body".write(to: noteURL, atomically: true, encoding: .utf8)

        let notificationCenter = NotificationCenter()
        let store = MacNoteStore(
            storageDirectory: sourceDirectory.url,
            userDefaults: makeIsolatedDefaults(),
            notificationCenter: notificationCenter,
            shouldStartMonitoringFileSystem: false,
            observeActivation: false
        )

        var didReceiveNotification = false
        let observer = notificationCenter.addObserver(
            forName: .storageDirectoryDidChange,
            object: nil,
            queue: nil
        ) { _ in
            didReceiveNotification = true
        }
        defer { notificationCenter.removeObserver(observer) }

        store.updateStorageDirectory(targetDirectory.url)

        for _ in 0..<20 where store.allNotes.isEmpty {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(didReceiveNotification)
        #expect(store.storageDirectory == targetDirectory.url)
        #expect(store.allNotes.map(\.title) == ["Loaded"])
    }

    @Test
    func loadNoteFromFileIgnoresUnsupportedFiles() throws {
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let textFile = tempDirectory.url.appendingPathComponent("Ignore.txt")
        try "Nope".write(to: textFile, atomically: true, encoding: .utf8)

        let store = MacNoteStore(
            storageDirectory: tempDirectory.url,
            userDefaults: makeIsolatedDefaults(),
            notificationCenter: NotificationCenter(),
            shouldStartMonitoringFileSystem: false,
            observeActivation: false
        )

        #expect(store.loadNoteFromFile(textFile) == nil)
    }
}
