//
//  ZettelControlWidget.swift
//  ZettelWidget
//
//  Created for Zetzel project
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
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("widget.new_note".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
        }
        .displayName("widget.display_name".localized)
        .description("widget.description".localized)
    }
}

struct Provider: ControlValueProvider {
    func currentValue() async throws -> Bool {
        return true
    }
    
    func previewValue(configuration: Void) -> Bool {
        return true
    }
}

// Extension to support localization
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}
