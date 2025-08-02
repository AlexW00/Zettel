//
//  LocalizationTestView.swift
//  Zettel
//
//  Created by GitHub Copilot on 02.08.25.
//
//  A debug view to test localization changes (for testing purposes only).
//

import SwiftUI

#if DEBUG
struct LocalizationTestView: View {
    @EnvironmentObject var localizationManager: LocalizationManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Localization Test View")
                .font(.title)
            
            VStack(alignment: .leading, spacing: 10) {
                LocalizedText("settings.appearance")
                LocalizedText("navigation.settings")
                LocalizedText("general.done")
                LocalizedText("theme.system")
                LocalizedText("note.title_placeholder")
            }
            
            Button("Force Localization Update") {
                localizationManager.forceUpdate()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Text("Current Language Update ID: \(localizationManager.languageUpdateId.uuidString.prefix(8))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct LocalizationTestView_Previews: PreviewProvider {
    static var previews: some View {
        LocalizationTestView()
            .environmentObject(LocalizationManager.shared)
    }
}
#endif
