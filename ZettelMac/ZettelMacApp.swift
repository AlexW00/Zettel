//
//  ZettelMacApp.swift
//  ZettelMac
//
//  macOS native Zettel application entry point.
//  Uses programmatic NSPanel windows for multi-window + pinning support.
//

import SwiftUI
import AppKit
import ZettelKit

@main
struct ZettelMacApp: App {
    @NSApplicationDelegateAdaptor(ZettelAppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window (Cmd+,)
        Settings {
            MacSettingsView()
                .frame(width: 480, height: 400)
        }
        .commands {
            // MARK: - File Menu
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    Task { @MainActor in
                        ZettelWindowManager.shared.newNoteInCurrentWindow()
                    }
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Window") {
                    Task { @MainActor in
                        ZettelWindowManager.shared.createWindow()
                    }
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("Open Note Picker") {
                    Task { @MainActor in
                        ZettelWindowManager.shared.togglePickerInCurrentWindow()
                    }
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            // Override Print with Pin
            CommandGroup(replacing: .printItem) {
                Button("Pin Window") {
                    Task { @MainActor in
                        ZettelWindowManager.shared.togglePinCurrentWindow()
                    }
                }
                .keyboardShortcut("p", modifiers: .command)
            }
        }
    }
}
