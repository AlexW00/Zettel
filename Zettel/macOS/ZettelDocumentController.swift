//
//  ZettelDocumentController.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import AppKit
import os.log

@objc(ZettelDocumentController)
@MainActor
final class ZettelDocumentController: NSDocumentController {
    private let logger = Logger(subsystem: "zettel-desktop", category: "ZettelDocumentController")
    private static var didInstallSharedInstance = false
    private let windowDocumentMap = NSMapTable<NSWindow, NoteDocument>.weakToWeakObjects()
    private weak var lastFocusedWindow: NSWindow?
    private weak var lastFocusedDocument: NoteDocument?
    private static let newWindowOffset = NSSize(width: 24, height: 24)

    static var sharedController: ZettelDocumentController {
        guard let controller = NSDocumentController.shared as? ZettelDocumentController else {
            fatalError("NSDocumentController.shared is not ZettelDocumentController. Call ZettelDocumentController.installSharedInstance() before accessing sharedController.")
        }
        return controller
    }

    static func installSharedInstance() {
        guard didInstallSharedInstance == false else { return }
        let controller = ZettelDocumentController()
        controller.logger.info("Installing ZettelDocumentController as shared instance: \(String(describing: NSDocumentController.shared), privacy: .public)")
        didInstallSharedInstance = true
    }

    private(set) var notesStore: NotesStore = .shared

    override var defaultType: String? {
        NoteDocument.documentUTI
    }

    func bootstrap(with store: NotesStore) {
        self.notesStore = store
    }

    func spawnUntitledDocument() {
        do {
            logger.debug("Spawning untitled document")
            guard let document = try makeUntitledDocument(ofType: NoteDocument.documentUTI) as? NoteDocument else { return }
            addDocument(document)
            document.makeWindowControllers()
            document.showWindows()
            logger.debug("Untitled document shown: \(String(describing: document), privacy: .public)")
        } catch {
            logger.error("Failed to spawn untitled document: \(error.localizedDescription, privacy: .public)")
            NSApp.presentError(error)
        }
    }

    func newDocumentInCurrentWindow() {
        logger.debug("Creating new document in current window")

        // Get the focused document
        guard let currentDocument = focusedNoteDocument() else {
            logger.debug("No focused document, spawning new window")
            spawnUntitledDocument()
            return
        }

        do {
            try currentDocument.flushPendingAutosave()
        } catch {
            logger.error("Autosave while creating new document failed: \(error.localizedDescription, privacy: .public)")
            NSApp.presentError(error)
            return
        }

        // Reuse the current window by preparing a new untitled session
        currentDocument.prepareUntitledSession()
        logger.debug("Prepared untitled session in current window")
    }

    override func newDocument(_ sender: Any?) {
        spawnUntitledDocument()
    }

    func openInNewWindow(url: URL) {
        do {
            logger.info("openInNewWindow url=\(url.path, privacy: .public)")
            let document = try makeDocument(withContentsOf: url, ofType: NoteDocument.documentUTI)
            addDocument(document)
            document.makeWindowControllers()
            document.showWindows()
            document.windowControllers.compactMap { $0.window }.forEach { window in
                window.makeKeyAndOrderFront(nil)
            }
        } catch {
            logger.error("openInNewWindow failed: \(error.localizedDescription, privacy: .public)")
            NSApp.presentError(error)
        }
    }

    override func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        let document = NoteDocument(notesStore: notesStore)
        document.prepareUntitledSession()
        return document
    }

    override func makeDocument(withContentsOf url: URL, ofType typeName: String) throws -> NSDocument {
        return try NoteDocument(existingFileURL: url, notesStore: notesStore)
    }

    // MARK: - Window Placement

    func suggestedFrameForNewWindow(defaultRect: NSRect) -> NSRect {
        var seen = Set<ObjectIdentifier>()
        var candidates: [NSWindow] = []

        func appendCandidate(_ window: NSWindow?) {
            guard let window else { return }
            let identifier = ObjectIdentifier(window)
            guard seen.insert(identifier).inserted else { return }
            guard noteDocument(for: window) != nil else { return }
            candidates.append(window)
        }

        appendCandidate(NSApp?.keyWindow)
        appendCandidate(NSApp?.mainWindow)
        appendCandidate(lastFocusedWindow)

        if let ordered = NSApp?.orderedWindows {
            for window in ordered {
                appendCandidate(window)
            }
        }

        for window in candidates {
            var frame = window.frame
            frame.origin.x += Self.newWindowOffset.width
            frame.origin.y -= Self.newWindowOffset.height
            return clampedFrame(frame, toVisibleFrameOf: window.screen)
        }

        return clampedFrame(defaultRect, toVisibleFrameOf: NSApp?.mainWindow?.screen)
    }

    private func clampedFrame(_ frame: NSRect, toVisibleFrameOf screen: NSScreen?) -> NSRect {
        guard let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return frame }
        var result = frame

        let minX = visibleFrame.minX
        let maxX = visibleFrame.maxX - result.width
        if maxX < minX {
            result.origin.x = minX
        } else {
            result.origin.x = min(max(result.origin.x, minX), maxX)
        }

        let minY = visibleFrame.minY
        let maxY = visibleFrame.maxY - result.height
        if maxY < minY {
            result.origin.y = minY
        } else {
            result.origin.y = min(max(result.origin.y, minY), maxY)
        }

        return result
    }

    // MARK: - Focus Tracking

    func register(window: NSWindow, for document: NoteDocument) {
        windowDocumentMap.setObject(document, forKey: window)
    }

    func unregister(window: NSWindow) {
        windowDocumentMap.removeObject(forKey: window)
        if lastFocusedWindow === window {
            lastFocusedWindow = nil
            lastFocusedDocument = nil
        }
    }

    func noteWindowDidFocus(window: NSWindow, document: NoteDocument) {
        register(window: window, for: document)
        lastFocusedWindow = window
        lastFocusedDocument = document
    }

    func noteWindowDidResign(window: NSWindow, document: NoteDocument) {
        guard lastFocusedWindow === window else { return }
        lastFocusedWindow = nil
        if let keyWindow = NSApp?.keyWindow, keyWindow !== window, let doc = noteDocument(for: keyWindow) {
            lastFocusedWindow = keyWindow
            lastFocusedDocument = doc
            return
        }
        if let mainWindow = NSApp?.mainWindow, mainWindow !== window, let doc = noteDocument(for: mainWindow) {
            lastFocusedWindow = mainWindow
            lastFocusedDocument = doc
            return
        }
        lastFocusedDocument = nil
    }

    func noteDocumentDidDetach(_ document: NoteDocument) {
        if lastFocusedDocument === document {
            lastFocusedDocument = nil
        }
    }

    func noteDocument(for window: NSWindow?) -> NoteDocument? {
        guard let window else { return nil }
        if let doc = window.windowController?.document as? NoteDocument {
            return doc
        }
        if let doc = document(for: window) as? NoteDocument {
            return doc
        }
        if let doc = windowDocumentMap.object(forKey: window) {
            return doc
        }
        return nil
    }

    func focusedNoteDocument() -> NoteDocument? {
        if let doc = noteDocument(for: NSApp?.keyWindow) {
            return doc
        }
        if let doc = noteDocument(for: NSApp?.mainWindow) {
            return doc
        }
        if let window = lastFocusedWindow, let doc = noteDocument(for: window) {
            return doc
        }
        if let windows = NSApp?.orderedWindows {
            for window in windows {
                if let doc = noteDocument(for: window) {
                    lastFocusedWindow = window
                    lastFocusedDocument = doc
                    return doc
                }
            }
        }
        if let doc = lastFocusedDocument {
            return doc
        }
        return nil
    }

    func noteDocuments() -> [NoteDocument] {
        documents.compactMap { $0 as? NoteDocument }
    }
}
