//
//  ContentView.swift
//  Zettel
//
//  Created for Zettel project
//

import SwiftUI

struct ContentView: View {
    @StateObject private var backgroundStore = BackgroundStore()
    
    var body: some View {
        ZStack {
            // Background layer - always behind everything, stays static during transitions
            BackgroundMediaView()
                .ignoresSafeArea()
            
            // Content layer - needs transparent backgrounds when custom bg is set
            MainView()
                .languageAware()
        }
        .environmentObject(backgroundStore)
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore())
        .environmentObject(ThemeStore())
        .environmentObject(LocalizationManager.shared)
        .environmentObject(DictationLocaleManager.shared)
}
