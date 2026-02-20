//
//  View+Cursor.swift
//  ZettelMac
//
//  Adds a reliable pointing-hand cursor on hover using NSCursor push/pop.
//  Unlike cursor-rect approaches, this works even when hitTest is overridden
//  or the view is hosted inside an NSHostingView.
//

import AppKit
import SwiftUI

extension View {
    /// Shows a pointing-hand cursor whenever the pointer is over this view.
    @ViewBuilder
    func pointingHandCursor() -> some View {
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
