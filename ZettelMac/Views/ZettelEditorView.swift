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

    // MARK: - Animation State

    /// Slide animation phase: controls which overlays are shown and which direction.
    private enum SlidePhase { case none, slideOut, slideIn }
    @State private var animationPhase: SlidePhase = .none

    /// Horizontal slide offset for the snapshot overlay (in points).
    @State private var slideOffset: CGFloat = 0
    /// Card-shift progress: 0 = normal positions, 1 = fully shifted.
    @State private var cardShiftAmount: CGFloat = 0
    /// Handle to the underlying NSScrollView so we can snapshot it before animating.
    @State private var editorHandle = MacTextEditorHandle()
    /// Snapshot used for the slide overlay (old note for out, new note for in).
    @State private var cardSnapshot: NSImage? = nil
    /// Snapshot of the old note sliding down into the card stack (slide-in only).
    @State private var oldNoteSnapshot: NSImage? = nil
    /// Global-coordinate frame of the live editor.
    @State private var editorGlobalFrame: CGRect = .zero
    /// Global X of the window's left edge (for edge-fade mask).
    @State private var windowGlobalMinX: CGFloat = 0
    /// Sidebar column visibility state for NavigationSplitView.
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    /// Whether any animation is currently running.
    private var isAnimating: Bool { animationPhase != .none }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NoteSidebar(state: state)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
                .navigationTitle("")
        } detail: {
            editorContent
                .frame(minWidth: 200, minHeight: 280)
                .background(.ultraThinMaterial)
        }
        .toolbar {
            // Centered note title — system handles geometry automatically.
            ToolbarItem(placement: .principal) {
                PrincipalTitleView(state: state)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings (⌘,)")
                .pointingHandCursor()

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
                .disabled(isAnimating)
                .pointingHandCursor()
            }
        }
        .onChange(of: state.isSidebarVisible) { _, visible in
            let target: NavigationSplitViewVisibility = visible ? .all : .detailOnly
            if columnVisibility != target {
                withAnimation { columnVisibility = target }
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).minX
        } action: { value in
            windowGlobalMinX = value
        }
        .onChange(of: columnVisibility) { _, newValue in
            let isVisible = (newValue != .detailOnly)
            if state.isSidebarVisible != isVisible {
                state.isSidebarVisible = isVisible
            }
        }
        .onChange(of: state.newNoteAnimationRequested) { _, requested in
            if requested {
                state.newNoteAnimationRequested = false
                animateNewNote()
            }
        }
        .onChange(of: state.openNoteAnimationRequested) { _, requested in
            if requested {
                state.openNoteAnimationRequested = false
                if let note = state.openNoteValue {
                    state.openNoteValue = nil
                    animateOpenNote(note: note)
                }
            }
        }
        .onChange(of: state.note.title) { _, _ in
            // Skip during animation: the title is already being animated from
            // the pre-computed value kicked off at the start of the transition.
            guard !isAnimating else { return }
            Task { @MainActor in
                ZettelWindowManager.shared.updateWindowTitle(id: state.windowId)
            }
        }
    }

    // MARK: - New-Note Animation (Slide-Out)

    /// Runs the slide-out + card-shift-up + content-swap sequence.
    /// The current note slides to the left, revealing the new note beneath.
    private func animateNewNote() {
        guard animationPhase == .none else { return }

        // If the current note was never saved (no content, never persisted), skip the
        // swoosh animation — just swap content and update the title instantly.
        let noteIsEmpty = state.persistedFilename == nil &&
            state.note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if noteIsEmpty {
            state.clearToNewNote()
            ZettelWindowManager.shared.updateWindowTitle(id: state.windowId)
            return
        }
        // Capture the top card as a plain NSImage *before* we start animating.
        let snap = editorHandle.snapshot()

        // Pre-compute the new note title so the titlebar animation can start
        // concurrently with the slide instead of waiting for clearToNewNote().
        let newTitle = DefaultTitleTemplateManager.shared.generateTitle(for: Date())
        ZettelWindowManager.shared.animateWindowTitle(
            id: state.windowId, to: newTitle, duration: 0.22
        )

        // Set animating flag + snapshot atomically with animations disabled so
        // the live editor's opacity change (1→0) is never caught by an implicit
        // animation context.
        var startT = Transaction()
        startT.disablesAnimations = true
        withTransaction(startT) {
            cardSnapshot = snap
            slideOffset = 0
            animationPhase = .slideOut
        }

        // Phase 1: slide the snapshot to the left
        withAnimation(.easeOut(duration: 0.22)) {
            slideOffset = -editorGlobalFrame.width
        }
        // Phase 1b: bottom cards shift up, new card appears
        withAnimation(.easeOut(duration: 0.22).delay(0.02)) {
            cardShiftAmount = 1.0
        }

        // Phase 2: slide done — swap content and reset everything instantly.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.25))

            state.clearToNewNote()
            ZettelWindowManager.shared.updateWindowTitleSilently(id: state.windowId)

            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                slideOffset = 0
                cardShiftAmount = 0
                animationPhase = .none
                cardSnapshot = nil
            }
        }
    }

    // MARK: - Open-Note Animation (Slide-In)

    /// Runs the slide-in + card-shift-down sequence when opening
    /// a note from the sidebar.
    private func animateOpenNote(note: Note) {
        guard animationPhase == .none else { return }

        // Don't animate if clicking the already-selected note
        guard note.id != state.note.id else { return }

        // 1. Capture old note snapshot (editor still visible with old content)
        let oldSnap = editorHandle.snapshot()

        // Animate titlebar to the new note's title
        let newTitle = note.title.isEmpty ? note.autoGeneratedTitle : note.title
        ZettelWindowManager.shared.animateWindowTitle(
            id: state.windowId, to: newTitle, duration: 0.22
        )

        // 2. Set initial animation state: hide live editor, show old note snapshot
        var startT = Transaction()
        startT.disablesAnimations = true
        withTransaction(startT) {
            oldNoteSnapshot = oldSnap
            animationPhase = .slideIn
        }

        // Start stack shift DOWN immediately (old note slides to card 2, card 2 → card 3)
        withAnimation(.easeOut(duration: 0.25)) {
            cardShiftAmount = 1.0
        }

        // 3. Swap to new note (editor is hidden via opacity 0, user doesn't see swap)
        state.saveNow()
        state.loadNote(note)

        // 4. Wait for NSTextView to render new content, then capture + slide in
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))

            let newSnap = editorHandle.snapshot()

            // 5. Set slide snapshot at off-screen left position (animations disabled)
            var snapT = Transaction()
            snapT.disablesAnimations = true
            withTransaction(snapT) {
                cardSnapshot = newSnap
                slideOffset = -editorGlobalFrame.width
            }

            // 6. Animate slide in from the left
            withAnimation(.spring(duration: 0.20, bounce: 0.06)) {
                slideOffset = 0
            }

            // 7. Wait for both animations to complete, then reset
            try? await Task.sleep(for: .seconds(0.22))

            ZettelWindowManager.shared.updateWindowTitleSilently(id: state.windowId)

            var resetT = Transaction()
            resetT.disablesAnimations = true
            withTransaction(resetT) {
                slideOffset = 0
                cardShiftAmount = 0
                animationPhase = .none
                cardSnapshot = nil
                oldNoteSnapshot = nil
            }

            // Restore keyboard focus to the editor
            editorHandle.focusEditor()
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
            ? Color(red: 0.30, green: 0.30, blue: 0.31)
            : Color(nsColor: .textBackgroundColor)
    }

    /// Middle card — slightly darker than top in light mode for clearer separation
    private var card2Fill: Color {
        colorScheme == .dark
            ? Color(red: 0.25, green: 0.25, blue: 0.26)
            : Color(red: 0.94, green: 0.94, blue: 0.94)
    }

    /// Back card — noticeably darker than middle to reinforce depth
    private var card3Fill: Color {
        colorScheme == .dark
            ? Color(red: 0.21, green: 0.21, blue: 0.22)
            : Color(red: 0.88, green: 0.88, blue: 0.88)
    }

    /// Stroke used as the card border — very subtle in both modes
    private var cardBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color.black.opacity(0.08)
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
            // Animated overlays sit on top during transitions and are
            // pixel-identical at t=0 and t=1 to the static cards / live editor,
            // so removing them on instant reset is completely invisible.

            // Card 3 — rest position (back)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(card3Fill)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(cardBorderColor, lineWidth: 0.5)
                }
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.28 : 0.06),
                    radius: colorScheme == .dark ? 8 : 6,
                    y: colorScheme == .dark ? 3 : 2
                )
                .padding(.horizontal, narrowStep * 2)
                .animation(.easeInOut(duration: 0.4), value: colorScheme)

            // Card 2 — rest position (middle)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(card2Fill)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(cardBorderColor, lineWidth: 0.5)
                }
                // SHADOW-2 REMOVED
                .padding(.horizontal, narrowStep)
                .padding(.bottom, peekAmount)
                .animation(.easeInOut(duration: 0.4), value: colorScheme)

            // ── Animated overlays: SHIFT UP (slide-out / new note creation) ──
            // At t=0 they match the static cards; at t=1 they match one level up.
            if animationPhase == .slideOut {
                // New card: fades in at Card 3's exact rest position.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(card3Fill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(cardBorderColor, lineWidth: 0.5)
                    }
                    .padding(.horizontal, narrowStep * 2)
                    .opacity(cardShiftAmount)

                // Card 3 clone: slides pos3 → pos2, cross-fades to look like Card 2.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(card3Fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(card2Fill)
                            .opacity(cardShiftAmount)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(cardBorderColor, lineWidth: 0.5)
                    }
                    .padding(.horizontal, narrowStep * (2 - cardShiftAmount))
                    .padding(.bottom, peekAmount * cardShiftAmount)

                // Card 2 clone: slides pos2 → pos1, cross-fades to look like editor card.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(card2Fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(cardFill)
                            .opacity(cardShiftAmount)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(cardBorderColor, lineWidth: 0.5)
                    }
                    .padding(.horizontal, narrowStep * (1 - cardShiftAmount))
                    .padding(.bottom, peekAmount + peekAmount * cardShiftAmount)
            }

            // ── Animated overlays: SHIFT DOWN (slide-in / open from sidebar) ─
            // At t=0 they match the static cards; at t=1 they match one level down.
            if animationPhase == .slideIn {
                // Card 2 clone: slides pos2 → pos3, cross-fades card2→card3
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(card2Fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(card3Fill)
                            .opacity(cardShiftAmount)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(cardBorderColor, lineWidth: 0.5)
                    }
                    .padding(.horizontal, narrowStep * (1 + cardShiftAmount))
                    .padding(.bottom, peekAmount - peekAmount * cardShiftAmount)

                // Old note snapshot: slides pos1 → pos2, content fades, fill cross-fades
                if let oldSnap = oldNoteSnapshot {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(card2Fill)
                                .opacity(cardShiftAmount)
                        )
                        .overlay(
                            Image(nsImage: oldSnap)
                                .resizable()
                                .opacity(1 - cardShiftAmount)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(cardBorderColor, lineWidth: 0.5)
                        }
                        .padding(.horizontal, narrowStep * cardShiftAmount)
                        .padding(.bottom, peekAmount * 2 - peekAmount * cardShiftAmount)
                }
            }

            // ── Card 1: live editor (always in tree) + snapshot overlays ──────
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
                    .animation(.easeInOut(duration: 0.4), value: colorScheme)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(cardBorderColor, lineWidth: 0.5)
                    .animation(.easeInOut(duration: 0.4), value: colorScheme)
            }
            // SHADOW-6 REMOVED
            .opacity(isAnimating ? 0 : 1)
            .allowsHitTesting(!isAnimating)
            .padding(.bottom, peekAmount * 2)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                editorGlobalFrame = frame
            }

            // Slide snapshot overlay — used during both slide-out and slide-in.
            // Slide-out: offset animates 0 → -width (slides left off screen).
            // Slide-in:  offset animates -width → 0 (slides in from the left).
            if isAnimating, let snapshot = cardSnapshot {
                let snapSize = snapshot.size
                Image(nsImage: snapshot)
                    .resizable()
                    .frame(width: snapSize.width, height: snapSize.height)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(cardFill)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(cardBorderColor, lineWidth: 0.5)
                    }
                    .mask {
                        // Fade out the left edge as the snapshot approaches the window edge,
                        // but only when the sidebar is expanded (otherwise the editor fills
                        // the full window width and no left-edge clipping is needed).
                        if columnVisibility != .detailOnly {
                            let fadeWidth: CGFloat = 36
                            let snapshotLeft = editorGlobalFrame.minX + slideOffset
                            let overlap = max(0, windowGlobalMinX - snapshotLeft)

                            HStack(spacing: 0) {
                                if overlap > 0 {
                                    Color.clear.frame(width: overlap)
                                }
                                LinearGradient(
                                    colors: [.clear, .black],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: fadeWidth)
                                Color.black
                            }
                            .frame(maxHeight: .infinity)
                        } else {
                            Color.black
                        }
                    }
                    .offset(x: slideOffset)
                    .allowsHitTesting(false)
                    .padding(.bottom, peekAmount * 2)
            }
        }
        .padding(outerPad)
    }
}

// MARK: - Principal Title View

/// Centered toolbar title with click-to-edit support.
/// Clicking the title opens a floating edit field below it (Raycast-style).
private struct PrincipalTitleView: View {
    @Bindable var state: ZettelWindowState
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Text(state.displayTitle)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(minWidth: 40, maxWidth: 300)
            .contentShape(Rectangle())
            .onTapGesture { startEditing() }
            .pointingHandCursor()
            .padding(.horizontal, 8)
            .popover(isPresented: $isEditing, arrowEdge: .bottom) {
                TextField("", text: $editText)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit { commitEdit() }
                    .onExitCommand { cancelEdit() }
                    .frame(width: 220)
                    .padding(8)
                    .onAppear {
                        DispatchQueue.main.async {
                            isFocused = true
                            DispatchQueue.main.async {
                                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                            }
                        }
                    }
            }
            .onChange(of: state.displayTitle) { _, _ in
                if isEditing { cancelEdit() }
            }
    }

    private func startEditing() {
        editText = state.displayTitle
        isEditing = true
    }

    private func commitEdit() {
        guard isEditing else { return }
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            state.updateTitle(trimmed)
            ZettelWindowManager.shared.updateWindowTitle(id: state.windowId)
        }
        isEditing = false
        isFocused = false
    }

    private func cancelEdit() {
        isEditing = false
        isFocused = false
    }
}
