//
//  ContentView.swift
//  Zettel
//
//  Created for Zettel project
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainView()
            .languageAware()
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore())
        .environmentObject(ThemeStore())
        .environmentObject(LocalizationManager.shared)
}
