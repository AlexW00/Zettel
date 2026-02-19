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
        
        // Configure UIKit appearances for transparent backgrounds
        configureTransparentNavigationAppearance()
    }
    
    /// Configures UIKit navigation-related appearances to be transparent
    /// This allows custom backgrounds to show through NavigationStack
    private func configureTransparentNavigationAppearance() {
        // Make UINavigationBar background transparent
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.backgroundColor = .clear
        navBarAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        // Make table/list backgrounds transparent (for Form, List, etc.)
        UITableView.appearance().backgroundColor = .clear
        
        // Make collection view backgrounds transparent
        UICollectionView.appearance().backgroundColor = .clear
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
