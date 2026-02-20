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

    // MARK: - Card Colors

    private var cardFill: Color {
        colorScheme == .dark
            ? Color(red: 0.24, green: 0.24, blue: 0.25)
            : Color(nsColor: .textBackgroundColor)
    }

    /// Middle card — slightly darker than top in light mode for clearer separation
    private var card2Fill: Color {
        colorScheme == .dark
            ? Color(red: 0.20, green: 0.20, blue: 0.21)
            : Color(red: 0.97, green: 0.97, blue: 0.97)
    }

    /// Back card — subtle but visibly darker than the middle card in light mode
    /// (dark-mode tuned to be lighter so the stack doesn't read like a heavy slab)
    private var card3Fill: Color {
        colorScheme == .dark
            ? Color(red: 0.19, green: 0.19, blue: 0.20)
            : Color(red: 0.95, green: 0.95, blue: 0.95)
    }

    // MARK: - Stacked Card Layout

    /// Margin from the window edge to the outermost (back) card
    private let outerPad: CGFloat = 12
    /// How many points each card peeks out below the card in front of it
    private let peekAmount: CGFloat = 6
    /// How many points narrower each background card is (per side)
    private let narrowStep: CGFloat = 8

    private var editorContent: some View {
        ZStack {
            // Card 3 (back) — defines the outermost bounds, narrowest
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(card3Fill)
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.28 : 0.06),
                    radius: colorScheme == .dark ? 8 : 6,
                    y: colorScheme == .dark ? 3 : 2
                )
                .padding(.horizontal, narrowStep * 2)

            // Card 2 (middle) — slightly wider, peekAmount shorter at bottom
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(card2Fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.035 : 0.03), lineWidth: 0.5)
                        .blendMode(.normal)
                )
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.30 : 0.10),
                    radius: colorScheme == .dark ? 8 : 6,
                    y: colorScheme == .dark ? 3 : 2
                )
                .padding(.horizontal, narrowStep)
                .padding(.bottom, peekAmount)

            // Card 1 (front/top) — full width, 2× peekAmount shorter at bottom
            MacTextEditor(
                text: Binding(
                    get: { state.note.content },
                    set: { state.updateContent($0) }
                ),
                allTags: allTagDisplayNames
            )
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardFill)
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.5 : 0.20),
                        radius: colorScheme == .dark ? 14 : 10,
                        y: colorScheme == .dark ? 5 : 4
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.bottom, peekAmount * 2)
        }
        .padding(outerPad)
    }
}
