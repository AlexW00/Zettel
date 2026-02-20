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
    /// Global-coordinate center of the toolbar button the genie should collapse toward.
    @State private var genieButtonCenter: CGPoint = .zero
    /// Global-coordinate origin of the snapshot view (used to convert button position
    /// into the shader's local coordinate system).
    @State private var snapshotGlobalOrigin: CGPoint = .zero

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
                .pointingHandCursor()
                .onGeometryChange(for: CGPoint.self) { proxy in
                    let f = proxy.frame(in: .global)
                    return CGPoint(x: f.midX, y: f.midY)
                } action: { newValue in
                    genieButtonCenter = newValue
                }

                Button {
                    ZettelWindowManager.shared.togglePin(id: state.windowId)
                } label: {
                    Label("Pin Window", systemImage: state.isPinned ? "pin.fill" : "pin")
                }
                .help("Pin Window (⌘P)")
                .pointingHandCursor()

                Button {
                    animateNewNote()
                } label: {
                    Label("New Note", systemImage: "plus")
                }
                .help("New Note (⌘N)")
                .disabled(isAnimatingNewNote)
                .pointingHandCursor()
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
        .onChange(of: state.isShowingPicker) { _, isShowing in
            if !isShowing {
                Task { @MainActor in
                    await Task.yield()
                    editorHandle.focusEditor()
                }
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
        let snap = editorHandle.snapshot()

        // Set animating flag + snapshot atomically with animations disabled so
        // the live editor's opacity change (1→0) is never caught by an implicit
        // animation context.
        var startT = Transaction()
        startT.disablesAnimations = true
        withTransaction(startT) {
            cardSnapshot = snap
            isAnimatingNewNote = true
        }

        // Phase 1: genie effect on the snapshot
        withAnimation(.easeIn(duration: 0.5)) {
            genieProgress = 1.0
        }
        // Phase 1b: bottom cards shift up, new card appears
        withAnimation(.easeInOut(duration: 0.4).delay(0.08)) {
            cardShiftAmount = 1.0
        }

        // Phase 2: genie done — swap content and reset everything instantly.
        // At cardShiftAmount=1 each background card is at the next card's exact frame,
        // so the instant reset to 0 is invisible behind the live editor.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.55))

            state.clearToNewNote()
            ZettelWindowManager.shared.updateWindowTitle(id: state.windowId)

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
            // ── Static background cards ───────────────────────────────────────
            // These stay fixed at their rest positions at all times.
            // Animated overlays (below) sit on top during the transition and are
            // pixel-identical at t=0 and t=1 to the static cards / live editor,
            // so removing them on instant reset is completely invisible.

            // Card 3 — rest position (back)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(card3Fill)
                // SHADOW-1 REMOVED
                .padding(.horizontal, narrowStep * 2)
                .opacity(isAnimatingNewNote ? 0 : 1)

            // Card 2 — rest position (middle)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(card2Fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.035 : 0.03), lineWidth: 0.5)
                        .blendMode(.normal)
                )
                // SHADOW-2 REMOVED
                .padding(.horizontal, narrowStep)
                .padding(.bottom, peekAmount)
                .opacity(isAnimatingNewNote ? 0 : 1)

            // ── Animated overlays (only present during transition) ────────────
            // At t=0 they are invisible (identical to the static cards beneath).
            // At t=1 they are identical to the live editor / static cards at rest,
            // so the instant reset that removes them causes zero visible change.
            if isAnimatingNewNote {
                // New card: fades in at Card 3's exact rest position.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(card3Fill)
                    // SHADOW-3 REMOVED
                    .padding(.horizontal, narrowStep * 2)
                    .opacity(cardShiftAmount)

                // Card 3 clone: slides pos3 → pos2, cross-fades to look like Card 2 at rest.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(card3Fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(card2Fill)
                            .opacity(cardShiftAmount)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                Color.black.opacity((colorScheme == .dark ? 0.035 : 0.03) * cardShiftAmount),
                                lineWidth: 0.5
                            )
                            .blendMode(.normal)
                    )
                    // SHADOW-4A REMOVED
                    // SHADOW-4B REMOVED
                    .padding(.horizontal, narrowStep * (2 - cardShiftAmount))
                    .padding(.bottom, peekAmount * cardShiftAmount)

                // Card 2 clone: slides pos2 → pos1, cross-fades to look like the live editor.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(card2Fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(cardFill)
                            .opacity(cardShiftAmount)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                Color.black.opacity((colorScheme == .dark ? 0.035 : 0.03) * (1 - cardShiftAmount)),
                                lineWidth: 0.5
                            )
                            .blendMode(.normal)
                    )
                    // SHADOW-5 REMOVED
                    .padding(.horizontal, narrowStep * (1 - cardShiftAmount))
                    .padding(.bottom, peekAmount + peekAmount * cardShiftAmount)
            }

            // ── Card 1: live editor (always in tree) + snapshot overlay ────
            // The MacTextEditor is NEVER removed from the view hierarchy.
            // Removing and re-inserting an NSViewRepresentable causes a
            // 1-frame rendering gap where its shadow is missing — the pop.

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
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            // SHADOW-6 REMOVED
            .opacity(isAnimatingNewNote ? 0 : 1)
            .allowsHitTesting(!isAnimatingNewNote)
            .padding(.bottom, peekAmount * 2)

            // Snapshot overlay — sits on top of the live editor during the
            // genie animation only; the editor underneath is hidden (opacity 0).
            if isAnimatingNewNote, let snapshot = cardSnapshot {
                let snapSize = snapshot.size
                Image(nsImage: snapshot)
                    .resizable()
                    .frame(width: snapSize.width, height: snapSize.height)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(cardFill)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onGeometryChange(for: CGPoint.self) { proxy in
                        let f = proxy.frame(in: .global)
                        return CGPoint(x: f.minX, y: f.minY)
                    } action: { newValue in
                        snapshotGlobalOrigin = newValue
                    }
                    .layerEffect(
                        ShaderLibrary.genieEffect(
                            .float2(snapSize),
                            .float2(CGPoint(
                                x: genieButtonCenter.x - snapshotGlobalOrigin.x,
                                y: genieButtonCenter.y - snapshotGlobalOrigin.y
                            )),
                            .float(genieProgress)
                        ),
                        maxSampleOffset: CGSize(width: snapSize.width, height: snapSize.height)
                    )
                    .allowsHitTesting(false)
                    .padding(.bottom, peekAmount * 2)
            }
        }
        .padding(outerPad)
    }
}
