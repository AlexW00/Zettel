//
//  DebugShortcutView.swift
//  Zettel
//
//  Debug view to test shortcut functionality without Shortcuts app
//

import SwiftUI

struct DebugShortcutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("debug.shortcuts.title".localized)
                .font(.title)
            
            Button("debug.shortcuts.trigger_simulate".localized) {
                // This simulates what the shortcut does
                NotificationCenter.default.post(
                    name: .createNewNoteFromShortcut,
                    object: nil
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    DebugShortcutView()
}
