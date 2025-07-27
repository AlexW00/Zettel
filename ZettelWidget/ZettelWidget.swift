//
//  ZettelWidget.swift
//  ZettelWidget
//
//  Created by Alex Weichart on 27.07.25.
//

import WidgetKit
import SwiftUI
import AppIntents

struct ZettelControlWidget: ControlWidget {
    static let kind: String = "ZettelControlWidget"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetButton(action: CreateNewNoteIntent()) {
                VStack(spacing: 2) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("New Note")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
        }
        .displayName("New Note")
        .description("Create a new note in Zettel")
    }
}

struct Provider: ControlValueProvider {
    var previewValue: Bool {
        return true
    }
    
    func currentValue() async throws -> Bool {
        return true
    }
}
