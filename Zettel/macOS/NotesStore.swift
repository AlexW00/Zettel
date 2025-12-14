//
//  NotesStore.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import Combine
import AppKit
import Foundation
import os.log

@MainActor
final class NotesStore: ObservableObject {
    struct NoteSummary: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let title: String
        let preview: String
        let characterCount: Int
        let lastModified: Date

        var accessoryDescription: String {
            preview
        }
    }

    enum ThemePreference: String, CaseIterable, Identifiable {
        case auto
        case light
        case dark

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .auto: return "Auto"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var appearance: NSAppearance? {
            switch self {
            case .auto: return nil
            case .light: return NSAppearance(named: .aqua)
            case .dark: return NSAppearance(named: .darkAqua)
            }
        }
    }

    enum StoreError: LocalizedError {
        case folderNotSelected
        case encodingFailure
        case decodingFailure
        case invalidName

        var errorDescription: String? {
            switch self {
            case .folderNotSelected: return "No notes folder selected."
            case .encodingFailure: return "Failed to encode note text."
            case .decodingFailure: return "Failed to decode note text."
            case .invalidName: return "Note names cannot be empty."
            }
        }
    }

    static let shared = NotesStore()

    @Published private(set) var notes: [NoteSummary] = []
    @Published private(set) var folderURL: URL?
    @Published var themePreference: ThemePreference {
        didSet {
            persistAppearancePreference(themePreference)
            applyAppearance(themePreference)
        }
    }
    @Published var titleTemplate: String {
        didSet { UserDefaults.standard.set(titleTemplate, forKey: Keys.titleTemplate) }
    }

    private var folderBookmarkData: Data? {
        didSet { UserDefaults.standard.set(folderBookmarkData, forKey: Keys.folderBookmark) }
    }

    private let logger = Logger(subsystem: "zettel-desktop", category: "NotesStore")
    private let fileManager = FileManager.default

    private struct Keys {
        static let folderBookmark = "NotesStore.folderBookmark"
        static let titleTemplate = "NotesStore.titleTemplate"
        static let themePreference = "NotesStore.themePreference"
    }

    private static let defaultFolderName = "Zettel"

    private init() {
        let storedTheme = UserDefaults.standard.string(forKey: Keys.themePreference)
        themePreference = ThemePreference(rawValue: storedTheme ?? "") ?? .auto
        titleTemplate = UserDefaults.standard.string(forKey: Keys.titleTemplate) ?? "{{date}} - {{time}}"
        if let bookmark = UserDefaults.standard.data(forKey: Keys.folderBookmark) {
            folderBookmarkData = bookmark
            restoreFolderAccess(from: bookmark)
        } else {
            ensureDefaultFolderIfNeeded()
        }
        applyAppearance(themePreference)
    }

    // MARK: - Folder Selection

    func setFolderURL(_ url: URL?, persistBookmark: Bool = true) {
        if let url {
            logger.info("NotesStore.setFolderURL called with url=\(url.path, privacy: .public) persist=\(persistBookmark, privacy: .public)")
            let bookmark: Data?
            if persistBookmark {
                do {
                    bookmark = try url.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                } catch {
                    bookmark = nil
                    logger.error("Failed to create security-scoped bookmark: \(error.localizedDescription, privacy: .public)")
                }
            } else {
                bookmark = nil
            }
            configureActiveFolder(url, bookmarkData: bookmark)
        } else {
            logger.info("NotesStore.setFolderURL clearing active folder; falling back to default.")
            folderURL = nil
            folderBookmarkData = nil
            notes = []
            ensureDefaultFolderIfNeeded()
        }
    }

    private func restoreFolderAccess(from bookmark: Data) {
        do {
            try FolderAccessManager.withAccess(to: bookmark) { accessibleURL in
                configureActiveFolder(accessibleURL, bookmarkData: bookmark)
            }
        } catch {
            logger.error("Failed to restore folder access: \(error.localizedDescription, privacy: .public)")
            folderBookmarkData = nil
            ensureDefaultFolderIfNeeded()
        }
    }

    private func ensureDefaultFolderIfNeeded() {
        guard folderURL == nil else {
            refreshNotes()
            return
        }
        guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Unable to resolve Application Support directory for default notes folder.")
            return
        }
        let bundleID = Bundle.main.bundleIdentifier ?? "zettel-desktop"
        let defaultURL = applicationSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(Self.defaultFolderName, isDirectory: true)
        do {
            if fileManager.fileExists(atPath: defaultURL.path) == false {
                try fileManager.createDirectory(at: defaultURL, withIntermediateDirectories: true)
            }
            configureActiveFolder(defaultURL, bookmarkData: nil)
            logger.debug("Configured default notes folder at \(defaultURL.path, privacy: .public)")
        } catch {
            logger.error("Failed to prepare default notes folder: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func configureActiveFolder(_ url: URL, bookmarkData: Data?) {
        folderURL = url
        folderBookmarkData = bookmarkData
        refreshNotes()
    }

    // MARK: - Appearance

    private func persistAppearancePreference(_ preference: ThemePreference) {
        UserDefaults.standard.set(preference.rawValue, forKey: Keys.themePreference)
    }

    func applyCurrentAppearance() {
        applyAppearance(themePreference)
    }

    private func applyAppearance(_ preference: ThemePreference) {
        guard let app = NSApp else { return }
        app.appearance = resolvedAppearance(for: preference)
    }

    private func resolvedAppearance(for preference: ThemePreference) -> NSAppearance? {
        switch preference {
        case .auto:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    var allowsGlassEffects: Bool {
        guard NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency == false else { return false }
        if #available(macOS 26, *) {
            return true
        }
        return false
    }

    // MARK: - Indexing

    func refreshNotes() {
        guard let folder = folderURL else {
            notes = []
            return
        }

        let loadSummaries = { try self.loadSummaries(in: folder) }
        do {
            if let bookmark = folderBookmarkData {
                notes = try FolderAccessManager.withAccess(to: bookmark) { _ in try loadSummaries() }
            } else {
                notes = try loadSummaries()
            }
            logger.info("Refreshed notes index: count=\(self.notes.count, privacy: .public) folder=\(folder.path, privacy: .public)")
        } catch {
            logger.error("Failed to refresh notes: \(error.localizedDescription, privacy: .public)")
            notes = []
        }
    }

    private func loadSummaries(in folder: URL) throws -> [NoteSummary] {
        let contents = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        var results: [NoteSummary] = []
        for fileURL in contents where fileURL.pathExtension.lowercased() == "md" {
            let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let preview = Self.previewText(from: text, limit: 80)
            let summary = NoteSummary(
                url: fileURL,
                title: fileURL.deletingPathExtension().lastPathComponent,
                preview: preview,
                characterCount: text.count,
                lastModified: resourceValues.contentModificationDate ?? .distantPast
            )
            results.append(summary)
        }

        return results.sorted { $0.lastModified > $1.lastModified }
    }

    private static func previewText(from text: String, limit: Int) -> String {
        // Collapse whitespace (including newlines) for a concise preview
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > limit else { return collapsed }
        let idx = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<idx]) + "…"
    }

    // MARK: - I/O

    func readText(at url: URL) throws -> String {
        logger.debug("readText begin url=\(url.path, privacy: .public) scoped=\(self.folderBookmarkData != nil, privacy: .public)")
        let performRead = { () throws -> String in
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            var result: Result<String, Error> = .failure(StoreError.decodingFailure)
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readingURL in
                do {
                    let text = try String(contentsOf: readingURL, encoding: .utf8)
                    result = .success(text)
                } catch let cocoaError as CocoaError where cocoaError.code == .fileReadInapplicableStringEncoding {
                    result = .failure(StoreError.decodingFailure)
                } catch {
                    result = .failure(error)
                }
            }
            if let coordinationError {
                self.logger.error("readText coordination error: \(coordinationError.localizedDescription, privacy: .public)")
                throw coordinationError
            }
            switch result {
            case .success(let text):
                self.logger.debug("readText success bytes=\(text.utf8.count, privacy: .public)")
                return text
            case .failure(let error):
                self.logger.error("readText failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }

        if let bookmark = folderBookmarkData {
            return try FolderAccessManager.withAccess(to: bookmark) { _ in try performRead() }
        } else {
            return try performRead()
        }
    }

    func writeText(_ text: String, to url: URL) throws {
        guard let data = text.data(using: .utf8) else {
            throw StoreError.encodingFailure
        }

        let performWrite = {
            self.logger.debug("writeText begin url=\(url.path, privacy: .public) bytes=\(data.count, privacy: .public)")
            let directory = url.deletingLastPathComponent()
            if self.fileManager.fileExists(atPath: directory.path) == false {
                try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                self.logger.debug("writeText created directory=\(directory.path, privacy: .public)")
            }
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            var writeError: Error?
            let options: NSFileCoordinator.WritingOptions = self.fileManager.fileExists(atPath: url.path) ? [.forReplacing] : []
            if options.contains(.forReplacing) {
                self.logger.debug("writeText using forReplacing at=\(url.lastPathComponent, privacy: .public)")
            } else {
                self.logger.debug("writeText creating new file at=\(url.lastPathComponent, privacy: .public)")
            }
            coordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) { writingURL in
                do {
                    try data.write(to: writingURL, options: .atomic)
                } catch {
                    writeError = error
                }
            }
            if let coordinationError {
                self.logger.error("writeText coordination error: \(coordinationError.localizedDescription, privacy: .public)")
                throw coordinationError
            }
            if let writeError {
                self.logger.error("writeText failed: \(writeError.localizedDescription, privacy: .public)")
                throw writeError
            }
            self.logger.info("writeText success url=\(url.path, privacy: .public) bytes=\(data.count, privacy: .public)")
        }

        do {
            if let bookmark = folderBookmarkData {
                try FolderAccessManager.withAccess(to: bookmark) { _ in try performWrite() }
            } else {
                try performWrite()
            }
            refreshNotes()
        } catch {
            logger.error("Failed to write note: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func urlForNewNote(using text: String) throws -> URL {
        try urlForNoteTitle(nil, fallbackText: text, createdAt: Date())
    }

    func urlForNewNote(preferredName: String?, fallbackText: String, createdAt: Date) throws -> URL {
        try urlForNoteTitle(preferredName, fallbackText: fallbackText, createdAt: createdAt)
    }

    func urlForNoteTitle(_ preferredName: String?, fallbackText: String, createdAt: Date) throws -> URL {
        guard let folder = folderURL else { throw StoreError.folderNotSelected }

        let trimmed = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let baseName: String
        if trimmed.isEmpty {
            baseName = Self.suggestedName(from: fallbackText, template: titleTemplate, date: createdAt)
        } else {
            baseName = Self.sanitizeFileName(trimmed)
        }
        return folder.appendingPathComponent(baseName).appendingPathExtension("md")
    }

    func renameNote(at url: URL, to proposedName: String) throws -> URL {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { throw StoreError.invalidName }

        let sanitized = Self.sanitizeFileName(trimmed)
        let baseFolder = url.deletingLastPathComponent()

        func targetURL(for suffix: Int?) -> URL {
            var name = sanitized
            if let suffix {
                name += " (\(suffix))"
            }
            var candidate = baseFolder.appendingPathComponent(name)
            let extensionComponent = url.pathExtension
            if extensionComponent.isEmpty == false {
                candidate.appendPathExtension(extensionComponent)
            }
            return candidate
        }

        var candidate = targetURL(for: nil)
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = targetURL(for: suffix)
            suffix += 1
        }

        let performRename = { () throws -> URL in
            try self.fileManager.moveItem(at: url, to: candidate)
            return candidate
        }

        let result: URL
        if let bookmark = folderBookmarkData {
            result = try FolderAccessManager.withAccess(to: bookmark) { _ in try performRename() }
        } else {
            result = try performRename()
        }

        // Schedule refresh outside of the current call stack so SwiftUI view updates
        // finish before @Published state mutates (avoids publishing-during-update logs).
        DispatchQueue.main.async { [weak self] in
            self?.refreshNotes()
        }
        return result
    }

    // MARK: - Deletion

    func deleteNote(_ summary: NoteSummary) throws {
        try deleteNote(at: summary.url)
    }

    func deleteNote(at url: URL) throws {
        let performDelete = {
            guard self.fileManager.fileExists(atPath: url.path) else { return }
            self.logger.debug("deleteNote begin url=\(url.path, privacy: .public)")
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            var deleteError: Error?
            coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { deletingURL in
                do {
                    try self.fileManager.removeItem(at: deletingURL)
                } catch {
                    deleteError = error
                }
            }
            if let coordinationError {
                self.logger.error("deleteNote coordination error: \(coordinationError.localizedDescription, privacy: .public)")
                throw coordinationError
            }
            if let deleteError {
                self.logger.error("deleteNote failed: \(deleteError.localizedDescription, privacy: .public)")
                throw deleteError
            }
            self.logger.info("deleteNote success url=\(url.path, privacy: .public)")
        }

        do {
            if let bookmark = folderBookmarkData {
                try FolderAccessManager.withAccess(to: bookmark) { _ in try performDelete() }
            } else {
                try performDelete()
            }
            refreshNotes()
        } catch {
            logger.error("Failed to delete note: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    // MARK: - Utilities

    static func suggestedName(from text: String, template: String, date: Date = Date()) -> String {
        let trimmed = text
            .split(separator: "\n")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = Calendar(identifier: .gregorian)

        let dateString: String
        if template.contains("{{date}}") {
            formatter.dateFormat = "yyyy-MM-dd"
            dateString = formatter.string(from: date)
        } else {
            dateString = ""
        }

        let timeString: String
        if template.contains("{{time}}") {
            formatter.dateFormat = "HH.mm.ss"
            timeString = formatter.string(from: date)
        } else {
            timeString = ""
        }

        var name = template
            .replacingOccurrences(of: "{{date}}", with: dateString)
            .replacingOccurrences(of: "{{time}}", with: timeString)

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = trimmed.isEmpty ? "Untitled Note" : trimmed
        }

        if name.contains("{{title}}") {
            name = name.replacingOccurrences(of: "{{title}}", with: trimmed)
        } else if name == template && !trimmed.isEmpty {
            name = trimmed
        }

        return sanitizeFileName(name)
    }

    private static func sanitizeFileName(_ rawValue: String) -> String {
        let disallowed = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let sanitized = rawValue
            .components(separatedBy: disallowed)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "Untitled Note" : sanitized
    }
}
