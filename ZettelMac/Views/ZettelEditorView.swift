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

    // MARK: - New-Note Animation State

    /// Genie shader progress: 0 = identity, 1 = fully collapsed.
    @State private var genieProgress: CGFloat = 0
    /// Whether the new-note transition is running.
    @State private var isAnimatingNewNote: Bool = false
    /// Card-shift progress: 0 = normal positions, 1 = shifted up.
    @State private var cardShiftAmount: CGFloat = 0
    /// Handle to the underlying NSScrollView so we can snapshot it before animating.
    @State private var editorHandle = MacTextEditorHandle()
    /// Bitmap snapshot of the top card captured just before the genie animation fires.
    /// We animate this image (a plain SwiftUI view) instead of the NSViewRepresentable
    /// editor, which cannot be captured by Metal layer effects.
    @State private var cardSnapshot: NSImage? = nil

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
                    animateNewNote()
                } label: {
                    Label("New Note", systemImage: "plus")
                }
                .help("New Note (⌘N)")
                .disabled(isAnimatingNewNote)
            }
        }
        .onChange(of: state.newNoteAnimationRequested) { _, requested in
            if requested {
                state.newNoteAnimationRequested = false
                animateNewNote()
            }
        }
        .onChange(of: state.note.title) { _, _ in
            Task { @MainActor in
                ZettelWindowManager.shared.updateWindowTitle(id: state.windowId)
            }
        }
    }

    // MARK: - New-Note Animation

    /// Runs the genie-out + card-shift + content-swap sequence.
    private func animateNewNote() {
        guard !isAnimatingNewNote else { return }

        // Capture the top card as a plain NSImage *before* we start animating.
        // This avoids applying a Metal layerEffect directly to the NSViewRepresentable
        // editor (which would show the red/yellow error badge).
        cardSnapshot = editorHandle.snapshot()
        isAnimatingNewNote = true

        // Phase 1: genie effect on the snapshot
        withAnimation(.easeIn(duration: 0.5)) {
            genieProgress = 1.0
        }
        // Phase 1b: bottom cards shift up, new card appears
        withAnimation(.easeInOut(duration: 0.4).delay(0.08)) {
            cardShiftAmount = 1.0
        }

        // Phase 2: after genie completes, swap content and reset
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.55))

            state.clearToNewNote()
            ZettelWindowManager.shared.updateWindowTitle(id: state.windowId)

            // Reset animation state without animation so the
            // new editor card appears exactly where card 2 was.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                genieProgress = 0
                cardShiftAmount = 0
                isAnimatingNewNote = false
                cardSnapshot = nil
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
            // New card (back-most) — fades in during animation,
            // occupies Card 3's original position.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(card3Fill)
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.18 : 0.04),
                    radius: 4, y: 2
                )
                .padding(.horizontal, narrowStep * 2)
                .opacity(cardShiftAmount)

            // Card 3 (back) — shifts up during animation
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(card3Fill)
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.28 : 0.06),
                    radius: colorScheme == .dark ? 8 : 6,
                    y: colorScheme == .dark ? 3 : 2
                )
                .padding(.horizontal, narrowStep * 2)
                .padding(.bottom, peekAmount * cardShiftAmount)

            // Card 2 (middle) — shifts up during animation
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
                .padding(.bottom, peekAmount + peekAmount * cardShiftAmount)

            // Card 1 (front/top)
            // During animation: show a bitmap snapshot of the card with the genie
            // Metal shader applied. We use a snapshot so the NSViewRepresentable
            // text editor is never subjected to layerEffect (which would show the
            // red/yellow error badge on AppKit-backed views).
            // At rest: show the live editor as normal.
            if isAnimatingNewNote, let snapshot = cardSnapshot {
                let snapSize = snapshot.size
                Image(nsImage: snapshot)
                    .resizable()
                    .frame(width: snapSize.width, height: snapSize.height)
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
                    .layerEffect(
                        ShaderLibrary.genieEffect(
                            .float2(snapSize),
                            .float2(CGPoint(x: snapSize.width * 0.77, y: -20)),
                            .float(genieProgress)
                        ),
                        maxSampleOffset: CGSize(width: snapSize.width, height: snapSize.height)
                    )
                    .allowsHitTesting(false)
                    .padding(.bottom, peekAmount * 2)
            } else {
                MacTextEditor(
                    text: Binding(
                        get: { state.note.content },
                        set: { state.updateContent($0) }
                    ),
                    allTags: allTagDisplayNames,
                    handle: editorHandle
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
                .allowsHitTesting(true)
                .padding(.bottom, peekAmount * 2)
            }
        }
        .padding(outerPad)
    }
}
