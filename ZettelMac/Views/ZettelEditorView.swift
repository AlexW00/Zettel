//
//  ZettelEditorView.swift
//  ZettelMac
//
//  Main per-window view containing the title field, text editor,
//  toolbar buttons (pin, list, new), and the note picker overlay.
//  Toolbar items automatically receive Liquid Glass on macOS 26.
//

import SwiftUI
import ZettelKit

struct ZettelEditorView: View {
    @Bindable var state: ZettelWindowState

    var body: some View {
        ZStack {
            // Main editor
            editorContent

            // Note picker overlay
            if state.isShowingPicker {
                NotePicker(state: state)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.smooth(duration: 0.2), value: state.isShowingPicker)
        .frame(minWidth: 320, minHeight: 280)
        .background(.ultraThinMaterial)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // List / Picker button
                Button {
                    state.isShowingPicker.toggle()
                } label: {
                    Label("Browse Notes", systemImage: "list.bullet")
                }
                .help("Browse Notes (⌘O)")
                .keyboardShortcut("o", modifiers: .command)

                // Pin button
                Button {
                    ZettelWindowManager.shared.togglePin(id: state.windowId)
                } label: {
                    Label("Pin Window", systemImage: state.isPinned ? "pin.fill" : "pin")
                }
                .help("Pin Window (⌘P)")

                // New note button
                Button {
                    state.clearToNewNote()
                    ZettelWindowManager.shared.updateWindowTitle(id: state.windowId)
                } label: {
                    Label("New Note", systemImage: "plus")
                }
                .help("New Note (⌘N)")
            }
        }
        .onChange(of: state.note.title) { _, _ in
            Task { @MainActor in
                ZettelWindowManager.shared.updateWindowTitle(id: state.windowId)
            }
        }
    }

    // MARK: - Editor Content

    private var editorContent: some View {
        // Note content only — title is shown in the window titlebar
        MacTextEditor(
            text: Binding(
                get: { state.note.content },
                set: { state.updateContent($0) }
            )
        )
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(10)
    }
}
