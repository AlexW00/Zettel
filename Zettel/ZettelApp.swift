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
    
    init() {
        // Register app shortcuts
        ZettelAppShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(noteStore)
                .environmentObject(themeStore)
                .preferredColorScheme(themeStore.currentTheme.colorScheme)
                .onOpenURL { url in
                    handleOpenURL(url)
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
