//
//  CreateNewNoteIntent.swift
//  Zettel
//
//  Created for Zettel project
//

import AppIntents
import SwiftUI
import Foundation

/// App Intent for creating a new note via Shortcuts
struct CreateNewNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "shortcuts.create_new_note"
    static var description = IntentDescription("shortcuts.create_new_note_description")
    
    static var openAppWhenRun: Bool = true
    
    /// Performs the intent action
    func perform() async throws -> some IntentResult {
        // Post notification to trigger new note creation
        // This allows the app to handle confirmation dialogs if needed
        await MainActor.run {
            NotificationCenter.default.post(
                name: .createNewNoteFromShortcut,
                object: nil
            )
        }
        
        return .result()
    }
}

/// Extension to handle notification names
extension Notification.Name {
    static let createNewNoteFromShortcut = Notification.Name("createNewNoteFromShortcut")
    static let showNewNoteConfirmation = Notification.Name("showNewNoteConfirmation")
}

/// App Shortcuts Provider - makes the intent available in Shortcuts app
struct ZettelAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNewNoteIntent(),
            phrases: [
                "Create a new note in \(.applicationName)",
                "New note in \(.applicationName)",
                "Add note in \(.applicationName)"
            ],
            shortTitle: "shortcuts.new_note_short_title",
            systemImageName: "note.text.badge.plus"
        )
    }
}
