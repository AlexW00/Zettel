//
//  ZettelPanel.swift
//  ZettelMac
//
//  Custom NSPanel subclass for Zettel note windows.
//  Panels support floating above other windows and proper key handling.
//

import AppKit

/// Custom NSPanel that can become key and main window.
final class ZettelPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
    }
}
