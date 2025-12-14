//
//  ZettelApp.swift
//  Zettel
//
//  Created for Zettel project
//

import SwiftUI
import AppIntents

@main
struct ZettelApp: App {
    @StateObject private var noteStore = NoteStore()
    @StateObject private var themeStore = ThemeStore()
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var dictationLocaleManager = DictationLocaleManager.shared
    
    init() {
        // Register app shortcuts
        ZettelAppShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(noteStore)
                .environmentObject(themeStore)
                .environmentObject(localizationManager)
                .environmentObject(dictationLocaleManager)
                .preferredColorScheme(themeStore.currentTheme.colorScheme)
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                .onAppear {
                    // Start initial note loading after the UI appears
                    noteStore.startInitialNoteLoading()
                }
                .onChange(of: noteStore.hasCompletedInitialLoad) { _, completed in
                    if completed {
                        // Check for changelog after initial load completes
                        noteStore.checkAndShowChangelog()
                    }
                }
        }
    }
    
    private func handleOpenURL(_ url: URL) {
        guard url.pathExtension == "md" else { return }
        
        Task {
            await noteStore.loadExternalFile(url)
        }
    }
}
