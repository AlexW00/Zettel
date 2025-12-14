//
//  NoteWindowController.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import AppKit
import Combine
import SwiftUI
import os.log

private struct TitlebarAccessoryContent: View {
    @ObservedObject var document: NoteDocument
    @ObservedObject var state: NoteWindowState
    let leadingInset: CGFloat
    let trailingInset: CGFloat
    let onOpenNote: (NotesStore.NoteSummary) -> Void
    let onOpenNoteInNewWindow: (NotesStore.NoteSummary) -> Void
    let onCreateNote: () -> Void

    private var centeringOffset: CGFloat { (leadingInset - trailingInset) / 2 }

    var body: some View {
        ZStack(alignment: .trailing) {
            TitlebarTitleView(document: document, state: state)
                .padding(.leading, leadingInset)
                .padding(.trailing, trailingInset)
                .frame(maxWidth: .infinity)
                .offset(x: -centeringOffset)

            TitlebarControlsView(
                state: state,
                activeNoteURL: document.session.url ?? document.fileURL,
                onOpenNote: onOpenNote,
                onOpenNoteInNewWindow: onOpenNoteInNewWindow,
                onCreateNote: onCreateNote
            )
            .padding(.trailing, trailingInset)
        }
        .frame(height: 28)
    }
}

private final class TitlebarOverlayHostingView: NSHostingView<AnyView> {
    var leadingExclusion: CGFloat = 0

    override func hitTest(_ point: NSPoint) -> NSView? {
        if point.x < leadingExclusion {
            return nil
        }
        return super.hitTest(point)
    }
}

/// Window subclass that clamps the frame to a minimum size regardless of how the resize is initiated.
private final class NoteWindow: NSWindow {
    private let enforcedMinimumSize: NSSize

    init(contentRect: NSRect, minimumSize: NSSize, styleMask style: NSWindow.StyleMask, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool) {
        self.enforcedMinimumSize = minimumSize
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
    }

    private func clampedFrame(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        var rect = super.constrainFrameRect(frameRect, to: screen)
        rect.size.width = max(rect.size.width, enforcedMinimumSize.width)
        rect.size.height = max(rect.size.height, enforcedMinimumSize.height)
        return rect
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        clampedFrame(frameRect, to: screen)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        let clamped = clampedFrame(frameRect, to: screen)
        let current = frame
        var final = clamped
        if frameRect.size.width < enforcedMinimumSize.width {
            final.origin.x = current.origin.x
        }
        if frameRect.size.height < enforcedMinimumSize.height {
            final.origin.y = current.origin.y
        }
        super.setFrame(final, display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool) {
        let clamped = clampedFrame(frameRect, to: screen)
        let current = frame
        var final = clamped
        if frameRect.size.width < enforcedMinimumSize.width {
            final.origin.x = current.origin.x
        }
        if frameRect.size.height < enforcedMinimumSize.height {
            final.origin.y = current.origin.y
        }
        super.setFrame(final, display: flag, animate: animateFlag)
    }
}

@MainActor
final class NoteWindowController: NSWindowController, NSWindowDelegate {
    private static let defaultRect = NSRect(x: 0, y: 0, width: 720, height: 800)
    private static let minimumSize = NSSize(width: 500, height: 500)

    private static func initialFrame() -> NSRect {
        let controller = ZettelDocumentController.sharedController
        var rect = controller.suggestedFrameForNewWindow(defaultRect: Self.defaultRect)
        if rect.width < Self.minimumSize.width {
            rect.size.width = Self.minimumSize.width
        }
        if rect.height < Self.minimumSize.height {
            rect.size.height = Self.minimumSize.height
        }
        return rect
    }

    private let state = NoteWindowState()
    private let notesStore: NotesStore
    private var cancellables = Set<AnyCancellable>()
    private weak var hostingContentView: NSView?
    private weak var glassEffectView: NSView?

    private var titlebarHostingView: TitlebarOverlayHostingView?
    private var hostingController: NSHostingController<AnyView>!

    private let logger = Logger(subsystem: "zettel-desktop", category: "NoteWindowController")

    init(document: NoteDocument, notesStore: NotesStore) {
        self.notesStore = notesStore
        let rootView = AnyView(
            NoteWindowRootView(document: document, state: state)
                .environmentObject(notesStore)
        )
        self.hostingController = NSHostingController(rootView: rootView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        let initialRect = Self.initialFrame()
        let window = NoteWindow(
            contentRect: initialRect,
            minimumSize: Self.minimumSize,
            styleMask: [.titled, .closable, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // Hide unused standard buttons to match custom chrome
        if let miniButton = window.standardWindowButton(.miniaturizeButton) {
            miniButton.isHidden = true
            miniButton.isEnabled = false
        }
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        super.init(window: window)

        window.delegate = self
        contentViewController = hostingController
        window.contentView = hostingController.view
        hostingContentView = hostingController.view
        window.setFrame(initialRect, display: false)
        window.minSize = Self.minimumSize
        let minimumContentSize = window.contentRect(forFrameRect: NSRect(origin: .zero, size: Self.minimumSize)).size
        window.contentMinSize = minimumContentSize
        window.minFullScreenContentSize = minimumContentSize
        window.tabbingMode = .disallowed
        self.document = document
        window.title = document.session.displayName
        ZettelDocumentController.sharedController.register(window: window, for: document)

        installTitlebarAccessory()
        applySurfaceStyleIfNeeded()
        bindState()
        logger.info("NoteWindowController init for doc=\(document.session.displayName, privacy: .public)")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bindState() {
        if let document = document as? NoteDocument {
            document.$banner
                .receive(on: RunLoop.main)
                .sink { [weak self] banner in
                    self?.state.banner = banner
                }
                .store(in: &cancellables)
        }

        state.$isNotesPopoverVisible
            .removeDuplicates()
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.notesStore.refreshNotes()
                }
            }
            .store(in: &cancellables)

        notesStore.$themePreference
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applySurfaceStyleIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func installTitlebarAccessory() {
        guard let window,
              let container = window.standardWindowButton(.closeButton)?.superview,
              let document = document as? NoteDocument else { return }

        if let existingView = titlebarHostingView {
            existingView.removeFromSuperview()
            titlebarHostingView = nil
        }

        let rootView = titlebarRootView(for: document)
        let hostingView = TitlebarOverlayHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let insets = currentTitlebarInsets()
        hostingView.leadingExclusion = max(insets.leading, 0)
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        titlebarHostingView = hostingView
    }

    private func titlebarRootView(for document: NoteDocument) -> AnyView {
        let insets = currentTitlebarInsets()
        let leadingInset = max(insets.leading, 0)
        let trailingInset = max(insets.trailing, 0)
        return AnyView(
            TitlebarAccessoryContent(
                document: document,
                state: state,
                leadingInset: leadingInset,
                trailingInset: trailingInset,
                onOpenNote: { [weak self] summary in
                    self?.logger.info("Accessory onOpenNote invoked for \(summary.title, privacy: .public)")
                    self?.open(summary: summary, inNewWindow: false)
                },
                onOpenNoteInNewWindow: { [weak self] summary in
                    self?.logger.info("Accessory onOpenNoteInNewWindow invoked for \(summary.title, privacy: .public)")
                    self?.open(summary: summary, inNewWindow: true)
                },
                onCreateNote: {
                    ZettelDocumentController.sharedController.spawnUntitledDocument()
                }
            )
            .environmentObject(notesStore)
        )
    }

    private func refreshTitlebarAccessory(for document: NoteDocument) {
        guard let hostingView = titlebarHostingView else {
            installTitlebarAccessory()
            return
        }
        let insets = currentTitlebarInsets()
        hostingView.leadingExclusion = max(insets.leading, 0)
        hostingView.rootView = titlebarRootView(for: document)
    }

    private func currentTitlebarInsets() -> (leading: CGFloat, trailing: CGFloat) {
        guard let window else { return (leading: 72, trailing: 12) }
        window.standardWindowButton(.closeButton)?.superview?.layoutSubtreeIfNeeded()
        let buttonFrames = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton]
            .compactMap { type -> NSRect? in
                guard let button = window.standardWindowButton(type), !button.isHidden else {
                    return nil
                }
                return button.frame
            }
        let leading = (buttonFrames.map { $0.maxX }.max() ?? 0) + 12
        return (leading, 12)
    }

    func windowDidBecomeMain(_ notification: Notification) {
        updateWindowTitle()
        if let window, let document = document as? NoteDocument {
            ZettelDocumentController.sharedController.noteWindowDidFocus(window: window, document: document)
        }
    }

    func windowDidResignMain(_ notification: Notification) {
        updateWindowTitle()
        if let window, let document = document as? NoteDocument {
            ZettelDocumentController.sharedController.noteWindowDidResign(window: window, document: document)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if let window, let document = document as? NoteDocument {
            ZettelDocumentController.sharedController.noteWindowDidFocus(window: window, document: document)
        }
        applySurfaceStyleIfNeeded()
    }

    func windowDidResignKey(_ notification: Notification) {
        if let window, let document = document as? NoteDocument {
            ZettelDocumentController.sharedController.noteWindowDidResign(window: window, document: document)
        }
        applySurfaceStyleIfNeeded()
    }

    func windowDidResize(_ notification: Notification) {
        if let document = document as? NoteDocument {
            refreshTitlebarAccessory(for: document)
        }
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(
            width: max(frameSize.width, Self.minimumSize.width),
            height: max(frameSize.height, Self.minimumSize.height)
        )
    }

    func windowWillClose(_ notification: Notification) {
        state.isCommandPaletteVisible = false
        state.isNotesPopoverVisible = false
        cancellables.removeAll()
        if let window {
            ZettelDocumentController.sharedController.unregister(window: window)
        }
        if let document = document as? NoteDocument {
            ZettelDocumentController.sharedController.noteDocumentDidDetach(document)
        }
    }

    private func updateWindowTitle() {
        guard let window = window, let document = document as? NoteDocument else { return }
        window.title = document.session.displayName
    }

    func open(summary: NotesStore.NoteSummary, inNewWindow: Bool) {
        logger.info("open summary title=\(summary.title, privacy: .public) inNewWindow=\(inNewWindow, privacy: .public)")
        if inNewWindow {
            ZettelDocumentController.sharedController.openInNewWindow(url: summary.url)
            return
        }

        // Defer and replace the document instance to avoid publishing during view updates
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                guard let controller = NSDocumentController.shared as? ZettelDocumentController else { return }
                guard let newDoc = try controller.makeDocument(withContentsOf: summary.url, ofType: NoteDocument.documentUTI) as? NoteDocument else { return }

                // Ensure NSDocumentController tracks the new document
                controller.addDocument(newDoc)

                // Update SwiftUI root to observe the new document
                self.hostingController.rootView = AnyView(
                    NoteWindowRootView(document: newDoc, state: self.state)
                        .environmentObject(self.notesStore)
                )

                // Swap window<->document ownership
                if let oldDoc = self.document as? NoteDocument {
                    do {
                        try oldDoc.flushPendingAutosave()
                    } catch {
                        let nsError = error as NSError
                        let banner = ErrorBanner(message: nsError.localizedDescription, severity: .error, error: nsError, isPersistent: true)
                        oldDoc.banner = banner
                        self.state.banner = banner
                        return
                    }
                    // Remove old doc from controller tracking to avoid Save targeting it
                    controller.removeDocument(oldDoc)
                    oldDoc.removeWindowController(self)
                    if let window = self.window {
                        ZettelDocumentController.sharedController.unregister(window: window)
                    }
                    ZettelDocumentController.sharedController.noteDocumentDidDetach(oldDoc)
                }
                self.document = newDoc
                newDoc.addWindowController(self)
                // Rebind state sinks to the new document
                self.cancellables.removeAll()
                self.bindState()
                self.refreshTitlebarAccessory(for: newDoc)
                if let window = self.window {
                    ZettelDocumentController.sharedController.noteWindowDidFocus(window: window, document: newDoc)
                }

                // Close overlays and update title
                self.state.isCommandPaletteVisible = false
                self.state.isNotesPopoverVisible = false
                self.updateWindowTitle()
                self.logger.info("Replaced document with \(newDoc.session.displayName, privacy: .public)")

                // Ensure the window is key so command routing prefers this document
                self.window?.makeKeyAndOrderFront(nil)
            } catch {
                let nsError = error as NSError
                let banner = ErrorBanner(message: nsError.localizedDescription, severity: .error, error: nsError, isPersistent: true)
                if let currentDoc = self.document as? NoteDocument {
                    currentDoc.banner = banner
                }
                self.state.banner = banner
            }
        }
    }

    func applySurfaceStyleIfNeeded() {
        guard let window = window else { return }
        if notesStore.allowsGlassEffects {
            applyGlassSurface(to: window)
        } else {
            applyOpaqueSurface(to: window)
        }
    }

    private func applyGlassSurface(to window: NSWindow) {
        guard #available(macOS 26, *) else {
            applyOpaqueSurface(to: window)
            return
        }

        let contentView = hostingContentView ?? window.contentView
        let glassView: NSGlassEffectView
        if let existing = glassEffectView as? NSGlassEffectView {
            glassView = existing
        } else {
            let glass = NSGlassEffectView(frame: window.contentLayoutRect)
            glass.autoresizingMask = [.width, .height]
            glass.style = .regular
            glass.cornerRadius = 18
            glassEffectView = glass
            glassView = glass
        }

        if glassView.contentView !== contentView {
            contentView?.translatesAutoresizingMaskIntoConstraints = true
            contentView?.frame = glassView.bounds
            contentView?.autoresizingMask = [.width, .height]
            glassView.contentView = contentView
        }

        if window.contentView !== glassView {
            window.contentView = glassView
        }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.hasShadow = true
        window.isMovableByWindowBackground = true
    }

    private func applyOpaqueSurface(to window: NSWindow) {
        if let glassView = glassEffectView as? NSGlassEffectView,
           window.contentView === glassView,
           let contentView = hostingContentView {
            glassView.contentView = nil
            window.contentView = contentView
        }

        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.hasShadow = true
        window.isMovableByWindowBackground = true
    }
}
