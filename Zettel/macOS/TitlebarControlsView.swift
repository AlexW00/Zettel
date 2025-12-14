//
//  TitlebarControlsView.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import SwiftUI
import AppKit
import os.log

struct TitlebarControlsView: View {
    @EnvironmentObject private var notesStore: NotesStore
    @ObservedObject var state: NoteWindowState
    let activeNoteURL: URL?
    let onOpenNote: (NotesStore.NoteSummary) -> Void
    let onOpenNoteInNewWindow: (NotesStore.NoteSummary) -> Void
    let onCreateNote: () -> Void

    private let logger = Logger(subsystem: "zettel-desktop", category: "TitlebarControls")

    private var notesPopoverBinding: Binding<Bool> {
        Binding(
            get: { state.isNotesPopoverVisible },
            set: { state.isNotesPopoverVisible = $0 }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                logger.info("Notes button tapped; popover currently=\(state.isNotesPopoverVisible, privacy: .public)")
                state.isNotesPopoverVisible.toggle()
                logger.info("Notes popover toggled to=\(state.isNotesPopoverVisible, privacy: .public)")
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("Show Notes")
            .popover(isPresented: notesPopoverBinding, arrowEdge: .top) {
                NotesListPopoverView(
                    activeNoteURL: activeNoteURL,
                    onOpen: { summary in
                        logger.info("Popover onOpen received title=\(summary.title, privacy: .public)")
                        // Route via active window controller when possible; otherwise use provided closure.
                        DispatchQueue.main.async {
                            // Try keyWindow, then mainWindow, then any app window with a NoteWindowController
                            if let wc = NSApp.keyWindow?.windowController as? NoteWindowController {
                                self.logger.info("Routing open via keyWindow controller")
                                wc.open(summary: summary, inNewWindow: false)
                                return
                            }
                            if let wc = NSApp.mainWindow?.windowController as? NoteWindowController {
                                self.logger.info("Routing open via mainWindow controller")
                                wc.open(summary: summary, inNewWindow: false)
                                return
                            }
                            if let wc = NSApp.windows.compactMap({ $0.windowController as? NoteWindowController }).first {
                                self.logger.info("Routing open via first NoteWindowController in NSApp.windows")
                                wc.open(summary: summary, inNewWindow: false)
                                return
                            }
                            self.logger.error("No NoteWindowController found; opening via document controller (new window)")
                            ZettelDocumentController.sharedController.openInNewWindow(url: summary.url)
                        }
                    },
                    onOpenInNewWindow: { summary in
                        logger.info("Popover onOpenInNewWindow received title=\(summary.title, privacy: .public)")
                        DispatchQueue.main.async {
                            if let wc = NSApp.keyWindow?.windowController as? NoteWindowController {
                                self.logger.info("Routing open new-window via keyWindow controller")
                                wc.open(summary: summary, inNewWindow: true)
                                return
                            }
                            if let wc = NSApp.mainWindow?.windowController as? NoteWindowController {
                                self.logger.info("Routing open new-window via mainWindow controller")
                                wc.open(summary: summary, inNewWindow: true)
                                return
                            }
                            if let wc = NSApp.windows.compactMap({ $0.windowController as? NoteWindowController }).first {
                                self.logger.info("Routing open new-window via first NoteWindowController in NSApp.windows")
                                wc.open(summary: summary, inNewWindow: true)
                                return
                            }
                            self.logger.error("No NoteWindowController found; opening via document controller (new window)")
                            ZettelDocumentController.sharedController.openInNewWindow(url: summary.url)
                        }
                    }
                )
                .environmentObject(notesStore)
                .onAppear { logger.info("NotesListPopover appear") }
                .onDisappear { logger.info("NotesListPopover disappear") }
            }

            Button(action: onCreateNote) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("New Note")
        }
    }
}

#if DEBUG
struct TitlebarControlsView_Previews: PreviewProvider {
    static var previews: some View {
        TitlebarControlsView(
            state: NoteWindowState(),
            activeNoteURL: nil,
            onOpenNote: { _ in },
            onOpenNoteInNewWindow: { _ in },
            onCreateNote: {}
        )
        .frame(width: 220)
        .environmentObject(NotesStore.shared)
    }
}
#endif
