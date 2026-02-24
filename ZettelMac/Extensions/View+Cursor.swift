//
//  View+Cursor.swift
//  ZettelMac
//
//  Reliable pointing-hand cursor for SwiftUI views on macOS.
//
//  Strategy: overlay a transparent NSView subclass that overrides
//  resetCursorRects(). AppKit calls resetCursorRects() on the whole
//  view hierarchy whenever the window becomes key or the layout changes.
//  Because NSViewRepresentable overlays sit on top of SwiftUI's own text
//  views, the cursor rect registered here wins over the I-beam rects that
//  SwiftUI registers for Text views — regardless of textSelection state.
//

import AppKit
import SwiftUI

// MARK: - NSView with cursor rect override

private final class PointingHandNSView: NSView {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    // Accept first mouse so the very first click registers without needing a
    // prior activation click.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - NSViewRepresentable wrapper

private struct PointingHandCursorOverlay: NSViewRepresentable {
    func makeNSView(context: Context) -> PointingHandNSView {
        let v = PointingHandNSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }
    func updateNSView(_ nsView: PointingHandNSView, context: Context) {
        // Invalidate whenever layout changes so resetCursorRects is re-called.
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

// MARK: - View modifier

extension View {
    /// Overlays a transparent NSView that registers a pointing-hand cursor
    /// rect, reliably overriding the I-beam cursor that SwiftUI's Text views
    /// register through AppKit's cursor-rect system.
    @ViewBuilder
    func pointingHandCursor() -> some View {
        self.overlay(PointingHandCursorOverlay().allowsHitTesting(false))
    }
}
