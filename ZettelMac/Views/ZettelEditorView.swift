//
//  ZettelEditorView.swift
//  ZettelMac
//
//  Main per-window view containing the text editor,
//  toolbar buttons (pin, list, new), and the centered note picker modal.
//

import SwiftUI
import ZettelKit

struct ZettelEditorView: View {
    @Bindable var state: ZettelWindowState

    var body: some View {
        ZStack {
            editorContent
                .frame(minWidth: 320, minHeight: 280)
                .background(.ultraThinMaterial)

            if state.isShowingPicker {
                NotePickerModal(state: state)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: state.isShowingPicker)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    state.isShowingPicker.toggle()
                } label: {
                    Label("Browse Notes", systemImage: "list.bullet")
                }
                .help("Browse Notes (⌘O)")

                Button {
                    ZettelWindowManager.shared.togglePin(id: state.windowId)
                } label: {
                    Label("Pin Window", systemImage: state.isPinned ? "pin.fill" : "pin")
                }
                .help("Pin Window (⌘P)")

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
        MacTextEditor(
            text: Binding(
                get: { state.note.content },
                set: { state.updateContent($0) }
            )
        )
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(10)
    }
}
