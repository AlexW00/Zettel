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
        // Show welcome note on first launch, otherwise restore the last opened note
        if isFirstLaunch() {
            let welcomeNote = createWelcomeNote()
            ZettelWindowManager.shared.createWindow(note: welcomeNote)
        } else if let changelogNote = MacChangelogManager.shared.pendingChangelogNote() {
            // Show changelog note for this update
            ZettelWindowManager.shared.createWindow(note: changelogNote)
            MacChangelogManager.shared.markSeen()
        } else {
            // Try to restore the last opened note
            let restoredNote = restoreLastOpenedNote()
            ZettelWindowManager.shared.createWindow(note: restoredNote)
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
            defaultValue: "👋 Welcome to Zettel\n\nQuick start:\n\n* ⌘S - toggle sidebar\n* ⌘P - pin window on top\n* ⌘N - new note (⇧⌘N for a new window)\n\nJust start typing - your notes auto-save.\n\nPS: Zettel is also available for iOS\n\nHappy #notetaking ^^",
            comment: "macOS welcome note content with keyboard shortcuts"
        )
        return Note(title: title, content: content)
    }

    /// Restores the last opened note from the previous session.
    private func restoreLastOpenedNote() -> Note? {
        guard let filename = UserDefaults.standard.string(forKey: "lastOpenedNoteFilename") else {
            return nil
        }
        let fileURL = MacNoteStore.shared.storageDirectory.appendingPathComponent(filename)
        return MacNoteStore.shared.loadNoteFromFile(fileURL)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No visible windows — restore last note or create a new one
            let restoredNote = restoreLastOpenedNote()
            ZettelWindowManager.shared.createWindow(note: restoredNote)
        } else {
            // Focus all existing windows
            ZettelWindowManager.shared.focusAllWindows()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Only quit when the Dock icon is hidden AND no note windows remain.
        // The Settings window doesn't count — without this check, closing
        // Settings as the last window would quit the app unexpectedly.
        guard MacDockIconPreference.isHidden() else { return false }
        return ZettelWindowManager.shared.hasNoWindows
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
