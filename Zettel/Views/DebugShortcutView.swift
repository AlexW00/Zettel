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
            Text("Debug Shortcut Testing")
                .font(.title)
            
            Button("Trigger Shortcut (Simulate)") {
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
