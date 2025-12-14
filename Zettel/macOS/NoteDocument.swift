//
//  NoteDocument.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import AppKit
import Combine
import SwiftUI
import os.log

@objc(NoteDocument)
final class NoteDocument: NSDocument, ObservableObject {
    static let documentUTI = "public.plain-text"

    @Published private(set) var session: NoteSession
    @Published var banner: ErrorBanner?

    private let notesStore: NotesStore
    private var applyingExternalChange = false
    private var pendingAutosaveWorkItem: DispatchWorkItem?
    private var hasPendingAutosave = false
    private static let autosaveDebounceInterval: TimeInterval = 0.8
    private let logger = Logger(subsystem: "zettel-desktop", category: "NoteDocument")

    @MainActor
    init(notesStore: NotesStore) {
        self.notesStore = notesStore
        self.session = NoteSession()
        super.init()
        hasUndoManager = true
        fileType = Self.documentUTI
    }

    @MainActor
    convenience init(existingFileURL url: URL, notesStore: NotesStore) throws {
        self.init(notesStore: notesStore)
        try loadContents(from: url)
    }

    nonisolated override class var autosavesInPlace: Bool { false }

    override var windowNibName: NSNib.Name? { nil }

    // MARK: - Session Lifecycle

    func prepareUntitledSession() {
        logger.info("NoteDocument.prepareUntitledSession")
        let createdAt = Date()
        let provisionalTitle = NotesStore.suggestedName(from: "", template: notesStore.titleTemplate, date: createdAt)
        session = NoteSession(createdAt: createdAt, url: nil, text: "", provisionalTitle: provisionalTitle)
        fileURL = nil
        updateChangeCount(.changeCleared)
        // Leave the change count cleared so we don't create a file until the user starts typing.
        updateWindowMetadata()
    }

    @MainActor
    private func loadContents(from url: URL) throws {
        logger.debug("NoteDocument.loadContents begin url=\(url.path, privacy: .public)")
        let text = try notesStore.readText(at: url)
        session = NoteSession(url: url, text: text)
        session.provisionalTitle = nil
        fileURL = url
        updateChangeCount(.changeCleared)
        clearAutosaveState()
        updateWindowMetadata()
        logger.info("NoteDocument.loadContents success bytes=\(text.utf8.count, privacy: .public)")
    }

    nonisolated override func read(from url: URL, ofType typeName: String) throws {
        logger.debug("NSDocument.read(from:ofType:) url=\(url.path, privacy: .public) type=\(typeName, privacy: .public)")
        try MainActor.assumeIsolated { [self] in
            try loadContents(from: url)
        }
    }

    nonisolated override func write(to url: URL, ofType typeName: String) throws {
        logger.debug("NSDocument.write(to:ofType:) url=\(url.path, privacy: .public) type=\(typeName, privacy: .public)")
        try MainActor.assumeIsolated { [self] in
            try notesStore.writeText(session.text, to: url)
            applySuccessfulSave(to: url)
        }
    }

    private func resolveSaveURL() throws -> URL {
        if let url = session.url ?? fileURL {
            logger.debug("Reusing existing save URL \(url.path, privacy: .public)")
            return url
        }

        do {
            let resolvedURL = try notesStore.urlForNoteTitle(
                session.provisionalTitle,
                fallbackText: session.text,
                createdAt: session.createdAt
            )
            let normalizedTitle = resolvedURL.deletingPathExtension().lastPathComponent
            if session.provisionalTitle != normalizedTitle {
                session.provisionalTitle = normalizedTitle
                updateWindowMetadata()
            }
            logger.debug("Resolved new save URL \(resolvedURL.path, privacy: .public)")
            return resolvedURL
        } catch {
            logger.error("Failed to resolve save URL: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    override func save(_ sender: Any?) {
        logger.debug("save(_:) invoked with sender=\(String(describing: sender), privacy: .public)")
        do {
            try performSave()
            let displayName = session.displayName
            logger.info("Save completed from save(_:) for session \(displayName, privacy: .public)")
        } catch {
            logger.error("Save triggered from UI failed: \(error.localizedDescription, privacy: .public)")
            NSApp.presentError(error)
        }
    }

    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        do {
            try flushPendingAutosave()
        } catch {
            logger.error("Flush before close failed: \(error.localizedDescription, privacy: .public)")
            NSApp.presentError(error)
        }
        super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
    }

    func performSave(saveOperation: NSDocument.SaveOperationType = .saveOperation) throws {
        let operationDescription = String(describing: saveOperation)
        let fileURLDescription = String(describing: self.fileURL)
        self.logger.debug("NoteDocument.performSave begin op=\(operationDescription, privacy: .public) fileURL=\(fileURLDescription, privacy: .public)")
        let targetURL = try resolveSaveURL()
        do {
            let isFirstSave = (self.session.url ?? self.fileURL) == nil
            try self.notesStore.writeText(self.session.text, to: targetURL)
            applySuccessfulSave(to: targetURL)
            self.logger.info("Save completed for \(targetURL.path, privacy: .public) (firstSave=\(isFirstSave, privacy: .public))")
        } catch {
            self.logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    override func makeWindowControllers() {
        let controller = NoteWindowController(document: self, notesStore: notesStore)
        addWindowController(controller)
        controller.showWindow(self)
    }

    func applyTextChange(_ newValue: String) {
        guard !applyingExternalChange, newValue != session.text else { return }
        let previousText = session.text

        undoManager?.registerUndo(withTarget: self) { target in
            target.applyExternalTextChange(previousText)
        }
        undoManager?.setActionName("Edit Text")
        session.text = newValue
        markAsEdited()
    }

    private func applyExternalTextChange(_ newText: String) {
        applyingExternalChange = true
        session.text = newText
        applyingExternalChange = false
        markAsEdited()
    }

    @MainActor
    func reload(from url: URL) throws {
        logger.debug("NoteDocument.reload begin url=\(url.path, privacy: .public)")
        let originalSession = session
        do {
            let text = try notesStore.readText(at: url)
            undoManager?.beginUndoGrouping()
            undoManager?.registerUndo(withTarget: self) { target in
                target.applySession(originalSession)
            }
            session.url = url
            session.text = text
            session.provisionalTitle = nil
            fileURL = url
            undoManager?.endUndoGrouping()
            updateChangeCount(.changeCleared)
            clearAutosaveState()
            updateWindowMetadata()
            logger.info("NoteDocument.reload success bytes=\(text.utf8.count, privacy: .public)")
        } catch {
            logger.error("NoteDocument.reload failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func promptRename() {
        let alert = NSAlert()
        alert.messageText = "Rename Note"
        alert.informativeText = "Enter a new name for this note."
        let textField = NSTextField(string: session.displayName)
        textField.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = textField
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        _ = rename(to: textField.stringValue)
    }

    @discardableResult
    func rename(to proposedName: String) -> Bool {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            let error = NotesStore.StoreError.invalidName
            let nsError = error as NSError
            banner = ErrorBanner(
                message: error.localizedDescription,
                severity: .error,
                error: nsError,
                isPersistent: true
            )
            return false
        }

        if let url = session.url {
            do {
                let newURL = try notesStore.renameNote(at: url, to: trimmed)
                session.url = newURL
                session.provisionalTitle = nil
                fileURL = newURL
                updateWindowMetadata()
                return true
            } catch {
                let nsError = error as NSError
                banner = ErrorBanner(message: nsError.localizedDescription, severity: .error, error: nsError, isPersistent: true)
                return false
            }
        } else {
            session.provisionalTitle = trimmed
            updateWindowMetadata()
            return true
        }
    }

    private func applySession(_ session: NoteSession) {
        applyingExternalChange = true
        self.session = session
        applyingExternalChange = false
        updateWindowMetadata()
        markAsEdited()
    }

    private func markAsEdited(triggerAutosaveImmediately: Bool = false) {
        hasPendingAutosave = true
        updateChangeCount(.changeDone)
        windowControllers.first?.window?.isDocumentEdited = false
        scheduleAutosave(immediate: triggerAutosaveImmediately)
    }

    private func updateWindowMetadata() {
        guard let window = windowControllers.first?.window else { return }
        window.title = session.displayName
        window.isDocumentEdited = false
    }

    private func applySuccessfulSave(to url: URL) {
        session.url = url
        session.provisionalTitle = nil
        fileURL = url
        updateChangeCount(.changeCleared)
        clearAutosaveState()
        updateWindowMetadata()
    }

    private func scheduleAutosave(immediate: Bool = false) {
        pendingAutosaveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingAutosaveWorkItem = nil
            do {
                try self.performAutosave()
            } catch {
                // Errors are surfaced via banners; no additional handling needed here.
            }
        }

        pendingAutosaveWorkItem = workItem
        let delay: TimeInterval = immediate ? 0 : Self.autosaveDebounceInterval
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func performAutosave() throws {
        guard hasPendingAutosave else { return }
        do {
            try performSave(saveOperation: .autosaveInPlaceOperation)
            hasPendingAutosave = false
            logger.debug("Autosave completed for \(self.session.displayName, privacy: .public)")
        } catch {
            logger.error("Autosave failed: \(error.localizedDescription, privacy: .public)")
            let nsError = error as NSError
            banner = ErrorBanner(message: nsError.localizedDescription, severity: .error, error: nsError, isPersistent: true)
            throw error
        }
    }

    func flushPendingAutosave() throws {
        pendingAutosaveWorkItem?.cancel()
        pendingAutosaveWorkItem = nil
        guard hasPendingAutosave else { return }
        try performAutosave()
    }

    private func clearAutosaveState() {
        hasPendingAutosave = false
        pendingAutosaveWorkItem?.cancel()
        pendingAutosaveWorkItem = nil
        windowControllers.first?.window?.isDocumentEdited = false
    }

}
