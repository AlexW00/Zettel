//
//  SidebarCardTracker.swift
//  ZettelMac
//
//  Tracks the global-coordinate frames of sidebar note cards so the
//  genie animation can target a specific card's position.
//
//  This is intentionally NOT @Observable — frame changes happen on
//  every scroll / resize and should NOT trigger editor redraws.
//  The editor reads the tracker's state imperatively at animation start.
//

import Foundation

/// Tracks per-card geometry in the sidebar for genie animation targeting.
@MainActor
final class SidebarCardTracker {

    // MARK: - Card Frames (SwiftUI .global coordinate space)

    /// Global frame of each visible sidebar card, keyed by note ID.
    private var frames: [String: CGRect] = [:]

    /// Visible bounds of the sidebar's scroll content area in global coordinates.
    var sidebarVisibleBounds: CGRect = .zero

    // MARK: - Updates (called from NoteSidebar via onGeometryChange)

    func updateFrame(for noteId: String, frame: CGRect) {
        frames[noteId] = frame
    }

    func removeFrame(for noteId: String) {
        frames.removeValue(forKey: noteId)
    }

    func frame(for noteId: String) -> CGRect? {
        frames[noteId]
    }

    /// Returns the genie target point (global coordinates) for a note.
    ///
    /// - If the card is visible in the sidebar, returns its center.
    /// - If the card is scrolled off the top/bottom, clamps to the
    ///   nearest edge of the sidebar's visible bounds.
    /// - Returns `nil` if no frame data is available at all.
    func genieTarget(for noteId: String) -> CGPoint? {
        guard let cardFrame = frames[noteId] else {
            // Card not in the lazy grid (scrolled fully off-screen).
            // We don't know exactly whether it's above or below,
            // so return nil and let the caller fall back.
            return nil
        }

        let center = CGPoint(x: cardFrame.midX, y: cardFrame.midY)

        // If sidebar bounds aren't tracked yet, just return the center.
        guard !sidebarVisibleBounds.isEmpty else { return center }

        // Clamp vertically to the sidebar's visible area.
        if center.y < sidebarVisibleBounds.minY {
            return CGPoint(x: sidebarVisibleBounds.midX, y: sidebarVisibleBounds.minY + 8)
        }
        if center.y > sidebarVisibleBounds.maxY {
            return CGPoint(x: sidebarVisibleBounds.midX, y: sidebarVisibleBounds.maxY - 8)
        }

        return center
    }

    /// Removes all stored frames (e.g. when sidebar collapses).
    func clearAll() {
        frames.removeAll()
        sidebarVisibleBounds = .zero
    }
}
