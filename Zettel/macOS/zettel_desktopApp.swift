//
//  zettel_desktopApp.swift
//  zettel-desktop
//
//  Created by Alex Weichart on 26.10.25.
//

import SwiftUI
import AppKit
import os.log

@main
struct ZettelDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var notesStore = NotesStore.shared

    init() {
        ZettelDocumentController.installSharedInstance()
    }

    var body: some Scene {
        Settings {
            SettingsRootView()
                .environmentObject(notesStore)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note in Current Window") {
                    Self.commandLogger.debug("Cmd+N triggered (current window)")
                    ZettelDocumentController.sharedController.newDocumentInCurrentWindow()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Note in New Window") {
                    Self.commandLogger.debug("Shift+Cmd+N triggered (new window)")
                    NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    Self.commandLogger.debug("Save command invoked; attempting NSResponder save(_:) first.")

                    if NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil) {
                        Self.commandLogger.debug("Save routed via NSResponder chain.")
                        return
                    }

                    Self.commandLogger.debug("Responder chain had no target; locating focused NoteDocument.")

                    let controller = ZettelDocumentController.sharedController
                    let mainWindow = NSApp.mainWindow
                    let keyWindow = NSApp.keyWindow
                    let noteDocs = controller.noteDocuments()
                    let focusedDoc = controller.focusedNoteDocument()
                    Self.commandLogger.debug("Save diagnostics: mainWindow=\(String(describing: mainWindow), privacy: .public) keyWindow=\(String(describing: keyWindow), privacy: .public) docs=\(noteDocs.map { $0.session.displayName }, privacy: .public) focused=\(String(describing: focusedDoc?.session.displayName), privacy: .public)")

                    func performSave(on document: NoteDocument, source: String) {
                        do {
                            try document.performSave()
                            Self.commandLogger.debug("performSave() succeeded via \(source, privacy: .public) for \(document.session.displayName, privacy: .public)")
                        } catch {
                            Self.commandLogger.error("performSave() failed via \(source, privacy: .public): \(error.localizedDescription, privacy: .public)")
                            NSApp.presentError(error)
                        }
                    }

                    if let document = focusedDoc {
                        Self.commandLogger.debug("Save: using focused NoteDocument \(document.session.displayName, privacy: .public)")
                        performSave(on: document, source: "focus-tracker")
                        return
                    }

                    // If there is exactly one NoteDocument, it's safe to save it.
                    if noteDocs.count == 1, let onlyDoc = noteDocs.first {
                        Self.commandLogger.debug("Save: using only NoteDocument present \(onlyDoc.session.displayName, privacy: .public)")
                        performSave(on: onlyDoc, source: "only-document")
                        return
                    }

                    Self.commandLogger.error("Unable to find NoteDocument for save command. Beeping.")
                    NSSound.beep()
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            CommandGroup(after: .saveItem) {
                Button("Close Window") {
                    Self.commandLogger.debug("Cmd+W triggered; attempting performClose() via responder chain.")

                    if NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil) {
                        return
                    }

                    if let keyWindow = NSApp.keyWindow {
                        Self.commandLogger.debug("Cmd+W fallback: closing key window directly.")
                        keyWindow.performClose(nil)
                        return
                    }

                    if let document = ZettelDocumentController.sharedController.focusedNoteDocument() {
                        Self.commandLogger.debug("Cmd+W fallback: closing focused document \(document.session.displayName, privacy: .public)")
                        document.close()
                        return
                    }

                    Self.commandLogger.error("Cmd+W had no target. Beeping.")
                    NSSound.beep()
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandMenu("Note") {
                Button("New Note in Current Window") {
                    ZettelDocumentController.sharedController.newDocumentInCurrentWindow()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Note in New Window") {
                    NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Rename…") {
                    if let document = NSDocumentController.shared.currentDocument as? NoteDocument {
                        document.promptRename()
                    }
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])
                .disabled((NSDocumentController.shared.currentDocument as? NoteDocument) == nil)
            }
        }
    }
}

private extension ZettelDesktopApp {
    static let commandLogger = Logger(subsystem: "zettel-desktop", category: "Commands")
}
