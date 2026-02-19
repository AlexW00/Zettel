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
    @Environment(\.colorScheme) private var colorScheme

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

    /// All unique tag display names gathered from every note (including the one currently
    /// being edited so newly typed tags appear as suggestions without needing a save).
    private var allTagDisplayNames: [String] {
        var normalizedToDisplay: [String: String] = [:]
        for note in MacNoteStore.shared.allNotes {
            let combined = note.title + " " + note.content
            let (displayMap, _) = TagParser.extractNormalizedAndDisplay(from: combined)
            for (normalized, display) in displayMap where normalizedToDisplay[normalized] == nil {
                normalizedToDisplay[normalized] = display
            }
        }
        // Also extract from the current (possibly unsaved) note so newly typed tags
        // appear in the suggestion list immediately.
        let currentCombined = state.note.title + " " + state.note.content
        let (currentDisplayMap, _) = TagParser.extractNormalizedAndDisplay(from: currentCombined)
        for (normalized, display) in currentDisplayMap where normalizedToDisplay[normalized] == nil {
            normalizedToDisplay[normalized] = display
        }
        return Array(normalizedToDisplay.values)
    }

    private var editorContent: some View {
        MacTextEditor(
            text: Binding(
                get: { state.note.content },
                set: { state.updateContent($0) }
            ),
            allTags: allTagDisplayNames
        )
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color(red: 0.24, green: 0.24, blue: 0.25) // even lighter dark-gray for dark mode
                        : Color(nsColor: .textBackgroundColor)
                )
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08),
                    radius: colorScheme == .dark ? 10 : 6,
                    y: colorScheme == .dark ? 4 : 2
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(10)
    }
}
