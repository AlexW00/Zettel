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
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore())
        .environmentObject(ThemeStore())
}
