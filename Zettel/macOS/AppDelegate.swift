//
//  AppDelegate.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import AppKit
import os.log

final class AppDelegate: NSObject, NSApplicationDelegate {
    let notesStore = NotesStore.shared
    private let logger = Logger(subsystem: "zettel-desktop", category: "AppDelegate")
    
    override init() {
        ZettelDocumentController.installSharedInstance()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("App did finish launching. DocumentController=\(String(describing: type(of: NSDocumentController.shared)), privacy: .public) docs=\(NSDocumentController.shared.documents.count, privacy: .public)")
        ZettelDocumentController.sharedController.bootstrap(with: notesStore)
        notesStore.applyCurrentAppearance()
        GlobalHotkeyManager.shared.activationHandler = {
            ZettelDocumentController.sharedController.spawnUntitledDocument()
        }
        GlobalHotkeyManager.shared.registerDefaultHotkey()

        if documents.isEmpty {
            logger.info("No documents present; spawning untitled.")
            ZettelDocumentController.sharedController.spawnUntitledDocument()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag == false {
            ZettelDocumentController.sharedController.spawnUntitledDocument()
        }
        return true
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkeyManager.shared.unregister()
    }

    private var documents: [NSDocument] {
        NSDocumentController.shared.documents
    }
}
