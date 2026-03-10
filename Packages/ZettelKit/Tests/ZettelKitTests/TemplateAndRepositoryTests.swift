import Foundation
import Testing
@testable import ZettelKit

struct TemplateAndRepositoryTests {
    @Test
    func templateRenderingSupportsBuiltInPlaceholders() {
        let defaults = makeIsolatedDefaults()
        let manager = DefaultTitleTemplateManager(
            userDefaults: defaults,
            storageKey: "titleTemplate",
            timeZone: TimeZone(identifier: "Europe/Berlin")!
        )
        let date = makeDate(year: 2025, month: 10, day: 19, hour: 8, minute: 5, second: 4)

        manager.saveTemplate("{{weekday}} {{date}} {{shortDate}} {{time}}")

        #expect(manager.generateTitle(for: date) == "Sunday 19 Oct 2025 2025-10-19 10-05-04")
    }

    @Test
    func blankTemplateFallsBackToLegacyTitleFormat() {
        let defaults = makeIsolatedDefaults()
        let manager = DefaultTitleTemplateManager(
            userDefaults: defaults,
            storageKey: "blankTemplate",
            timeZone: TimeZone(identifier: "Europe/Berlin")!
        )
        let date = makeDate(year: 2025, month: 10, day: 19, hour: 8, minute: 5, second: 4)

        manager.saveTemplate("   ")

        #expect(manager.currentTemplate() == manager.fallbackTemplate)
        #expect(manager.generateTitle(for: date) == "2025-10-19 – 10-05-04")
    }

    @Test
    func templatePersistenceCanBeSavedAndCleared() {
        let defaults = makeIsolatedDefaults()
        let manager = DefaultTitleTemplateManager(userDefaults: defaults, storageKey: "persistedTemplate")

        manager.saveTemplate("{{weekday}}")
        #expect(manager.savedTemplate() == "{{weekday}}")

        manager.saveTemplate("")
        #expect(manager.savedTemplate() == nil)
    }

    @Test
    func repositoryLoadsOnlyMarkdownFilesAndPreservesMetadata() throws {
        let repository = NoteFileRepository()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let noteURL = tempDirectory.url.appendingPathComponent("Loaded.md")
        let createdAt = makeDate(year: 2024, month: 11, day: 1, hour: 7, minute: 0, second: 0)
        let modifiedAt = makeDate(year: 2024, month: 11, day: 2, hour: 7, minute: 0, second: 0)

        try "Body #tag".write(to: noteURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.creationDate: createdAt, .modificationDate: modifiedAt],
            ofItemAtPath: noteURL.path
        )
        try "ignore me".write(
            to: tempDirectory.url.appendingPathComponent("Ignored.txt"),
            atomically: true,
            encoding: .utf8
        )

        let notes = try repository.loadNotes(in: tempDirectory.url)

        #expect(notes.count == 1)
        #expect(notes.first?.title == "Loaded")
        #expect(notes.first?.createdAt == createdAt)
        #expect(notes.first?.modifiedAt == modifiedAt)
    }

    @Test
    func repositorySaveWritesNoteAndReturnsFinalFilename() throws {
        let repository = NoteFileRepository()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let note = Note(title: "Repository Save", content: "Body")
        let result = try repository.save(note, in: tempDirectory.url)

        #expect(result.filename == "Repository Save.md")
        #expect(FileManager.default.fileExists(atPath: result.fileURL.path))
        #expect(try String(contentsOf: result.fileURL, encoding: .utf8) == "Body")
    }

    @Test
    func repositoryRenameDeletesOriginalAfterSuccessfulSave() throws {
        let repository = NoteFileRepository()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let originalURL = tempDirectory.url.appendingPathComponent("Original.md")
        try "Old".write(to: originalURL, atomically: true, encoding: .utf8)

        let renamed = Note(title: "Renamed", content: "Updated")
        let result = try repository.save(renamed, in: tempDirectory.url, originalFilename: "Original.md")

        #expect(result.filename == "Renamed.md")
        #expect(!FileManager.default.fileExists(atPath: originalURL.path))
        #expect(FileManager.default.fileExists(atPath: tempDirectory.url.appendingPathComponent("Renamed.md").path))
    }

    @Test
    func repositoryDeleteRemovesExistingMarkdownFile() throws {
        let repository = NoteFileRepository()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let note = Note(title: "Delete Me", content: "")
        let fileURL = tempDirectory.url.appendingPathComponent(note.filename)
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        try repository.delete(note, from: tempDirectory.url)

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
}
