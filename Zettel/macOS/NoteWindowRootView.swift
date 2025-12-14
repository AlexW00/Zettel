//
//  NoteWindowRootView.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import SwiftUI
import AppKit
import os.log

struct NoteWindowRootView: View {
    @ObservedObject var document: NoteDocument
    @ObservedObject var state: NoteWindowState
    @EnvironmentObject private var notesStore: NotesStore
    @State private var paletteQuery: String = ""
    private let logger = Logger(subsystem: "zettel-desktop", category: "NoteWindowRootView")

    private var backgroundColor: Color {
        notesStore.allowsGlassEffects ? Color.clear : Color(nsColor: .windowBackgroundColor)
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundColor
                .ignoresSafeArea()
                .allowsHitTesting(false)

            NoteEditorView(document: document)
                .padding(.horizontal, 12)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.isCommandPaletteVisible {
                GeometryReader { geometry in
                    CommandPaletteView(
                        notes: notesStore.notes,
                        onOpen: { summary in open(note: summary, inNewWindow: false) },
                        onOpenInNewWindow: { summary in open(note: summary, inNewWindow: true) },
                        onDismiss: { state.isCommandPaletteVisible = false },
                        query: $paletteQuery
                    )
                    .frame(
                        maxWidth: min(420, geometry.size.width - 48),
                        maxHeight: min(360, geometry.size.height - 120)
                    )
                    .padding(.top, 68)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(5)
            }

            if let banner = state.banner ?? document.banner {
                ErrorBannerView(banner: banner) {
                    state.banner = nil
                    document.banner = nil
                }
                .padding(.horizontal, 32)
                .padding(.top, 12)
                .transition(.opacity)
                .zIndex(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowStyleConfigurator())
        .animation(.easeInOut(duration: 0.2), value: state.isCommandPaletteVisible)
        .onChange(of: state.isCommandPaletteVisible) { isVisible in
            if isVisible == false {
                paletteQuery = ""
            }
        }
    }

    private func open(note summary: NotesStore.NoteSummary, inNewWindow: Bool) {
        logger.info("RootView.open note title=\(summary.title, privacy: .public) inNewWindow=\(inNewWindow, privacy: .public)")
        if inNewWindow {
            ZettelDocumentController.sharedController.openInNewWindow(url: summary.url)
            state.isCommandPaletteVisible = false
            return
        }

        // Route through the window controller to avoid publishing during view updates
        if let wc = NSApp.keyWindow?.windowController as? NoteWindowController {
            wc.open(summary: summary, inNewWindow: false)
            return
        }

        // Fallback (should not be hit): defer reload
        DispatchQueue.main.async {
            do {
                try document.reload(from: summary.url)
                state.isCommandPaletteVisible = false
            } catch {
                let nsError = error as NSError
                let banner = ErrorBanner(message: nsError.localizedDescription, severity: .error, error: nsError, isPersistent: true)
                document.banner = banner
                state.banner = banner
            }
        }
    }
}

private struct WindowStyleConfigurator: NSViewRepresentable {
    @EnvironmentObject private var notesStore: NotesStore

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window,
              let controller = window.windowController as? NoteWindowController else { return }
        controller.applySurfaceStyleIfNeeded()
    }
}
