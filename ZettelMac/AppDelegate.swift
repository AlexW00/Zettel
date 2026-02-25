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

    private let hasLaunchedBeforeKey = "hasLaunchedBefore"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show welcome note on first launch, otherwise create empty window
        if isFirstLaunch() {
            let welcomeNote = createWelcomeNote()
            ZettelWindowManager.shared.createWindow(note: welcomeNote)
        } else {
            ZettelWindowManager.shared.createWindow()
        }
    }

    // MARK: - First Launch

    /// Returns `true` on the very first launch (or after the user resets the app).
    /// Sets the flag so subsequent launches return `false`.
    private func isFirstLaunch() -> Bool {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
            return true
        }
        return false
    }

    /// Creates a welcome note with macOS-specific keyboard shortcut tips.
    private func createWelcomeNote() -> Note {
        let title = String(
            localized: "mac.welcome.title",
            defaultValue: "Welcome to Zettel",
            comment: "macOS welcome note title"
        )
        let content = String(
            localized: "mac.welcome.content",
            defaultValue: "👋 Welcome to Zettel\n\nQuick start:\n\n* ⌘O - browse your notes\n* ⌘P - pin window on top\n* ⌘N - new note (⇧⌘N for a new window)\n\nJust start typing - your notes auto-save.\n\nPS: Zettel is also available for iOS\n\nHappy #notetaking ^^",
            comment: "macOS welcome note content with keyboard shortcuts"
        )
        return Note(title: title, content: content)
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
