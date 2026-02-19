//
//  ZettelAppDelegate.swift
//  ZettelMac
//
//  NSApplicationDelegate for managing app lifecycle and first window creation.
//

import AppKit
import SwiftUI
import ZettelKit

@MainActor
final class ZettelAppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the first empty Zettel window on launch
        ZettelWindowManager.shared.createWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No visible windows — create a new one
            ZettelWindowManager.shared.createWindow()
        } else {
            // Focus all existing windows
            ZettelWindowManager.shared.focusAllWindows()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app alive even with no windows (like TextEdit)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush all pending saves before quitting
        ZettelWindowManager.shared.saveAllWindows()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        guard url.pathExtension == "md" else { return false }

        Task { @MainActor in
            if let note = MacNoteStore.shared.loadNoteFromFile(url) {
                ZettelWindowManager.shared.createWindow(note: note)
            }
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.pathExtension == "md" else { continue }
            Task { @MainActor in
                if let note = MacNoteStore.shared.loadNoteFromFile(url) {
                    ZettelWindowManager.shared.createWindow(note: note)
                }
            }
        }
    }
}
