//
//  NoteSidebar.swift
//  ZettelMac
//
//  Native macOS sidebar for browsing and selecting notes.
//  Double-click a row or use the context menu to rename.
//

import AppKit
import SwiftUI
import ZettelKit

// MARK: - Sidebar

struct NoteSidebar: View {
    @Bindable var state: ZettelWindowState

    @State private var searchText = ""
    @State private var renamingNoteId: String? = nil
    @State private var renameText: String = ""

    /// ID of the note the mouse is currently hovering over.
    @State private var hoveredNoteId: String? = nil

    private var store: MacNoteStore { MacNoteStore.shared }

    private var filteredNotes: [Note] {
        let notes = store.allNotes
        let filtered: [Note] = searchText.isEmpty
            ? notes
            : notes.filter {
                $0.title.localizedStandardContains(searchText)
                || $0.content.localizedStandardContains(searchText)
            }
        return filtered.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Inline search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                TextField(
                    String(localized: "mac.sidebar.search_prompt", defaultValue: "Search Notes", comment: "Sidebar search placeholder"),
                    text: $searchText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit { renamingNoteId = nil }

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.primary.opacity(0.06)))
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)

            if store.isLoading && store.allNotes.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredNotes.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty
                        ? String(localized: "mac.sidebar.empty", defaultValue: "No Notes", comment: "Sidebar empty state title")
                        : String(localized: "mac.sidebar.no_results", defaultValue: "No Results", comment: "Sidebar no results title"),
                    systemImage: searchText.isEmpty ? "note.text" : "magnifyingglass",
                    description: searchText.isEmpty
                        ? Text(String(localized: "mac.sidebar.empty_description", defaultValue: "Create a note to get started", comment: "Sidebar empty state description"))
                        : Text(String(localized: "mac.sidebar.no_results_description", defaultValue: "No notes matching your search", comment: "Sidebar no results description"))
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(filteredNotes) { note in
                            NoteSidebarCard(
                                note: note,
                                isActive: note.id == state.note.id,
                                isHovered: note.id == hoveredNoteId,
                                isRenaming: Binding(
                                    get: { renamingNoteId == note.id },
                                    set: { if !$0 { renamingNoteId = nil } }
                                ),
                                renameText: $renameText,
                                onSelect: {
                                    selectNote(note)
                                },
                                onDoubleClick: { beginRename(note) },
                                onCommitRename: { commitRename(note) },
                                onCancelRename: { renamingNoteId = nil },
                                onHover: { isHovering in
                                    hoveredNoteId = isHovering ? note.id : nil
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.85).combined(with: .opacity),
                                removal: .scale(scale: 0.85).combined(with: .opacity)
                            ))
                            .contextMenu {
                                    Button { beginRename(note) } label: {
                                        Label(
                                            String(localized: "mac.sidebar.rename", defaultValue: "Rename", comment: "Sidebar rename action"),
                                            systemImage: "pencil"
                                        )
                                    }
                                    Button {
                                        ZettelWindowManager.shared.createWindow(note: note)
                                    } label: {
                                        Label(
                                            String(localized: "mac.sidebar.open_new_window", defaultValue: "Open in New Window", comment: "Sidebar context menu action"),
                                            systemImage: "macwindow.badge.plus"
                                        )
                                    }
                                    Button {
                                        let fileURL = MacNoteStore.shared.storageDirectory
                                            .appendingPathComponent(note.filename)
                                        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                                    } label: {
                                        Label(
                                            String(localized: "mac.sidebar.show_in_finder", defaultValue: "Show in Finder", comment: "Sidebar show in Finder action"),
                                            systemImage: "folder"
                                        )
                                    }
                                    Divider()
                                    Button(role: .destructive) { deleteNote(note) } label: {
                                        Label(
                                            String(localized: "mac.sidebar.delete", defaultValue: "Delete", comment: "Sidebar delete action"),
                                            systemImage: "trash"
                                        )
                                    }
                                }
                            }
                    }
                    .animation(.smooth(duration: 0.3), value: filteredNotes.map(\.id))
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }
        }
        .task {
            state.saveNow()
            await store.loadAllNotes()
        }
    }

    // MARK: - Selection

    private func selectNote(_ note: Note) {
        renamingNoteId = nil

        // Don't re-open the already-active note
        guard note.id != state.note.id else { return }

        state.openNoteValue = note
        state.openNoteAnimationRequested = true
    }

    // MARK: - Rename

    private func beginRename(_ note: Note) {
        renameText = note.title.isEmpty ? note.autoGeneratedTitle : note.title
        renamingNoteId = note.id
    }

    private func commitRename(_ note: Note) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            renamingNoteId = nil
            return
        }

        if note.id == state.note.id {
            // Current window's note — use state so dirty/autosave/title all update
            state.updateTitle(trimmed)
            Task { @MainActor in
                ZettelWindowManager.shared.updateWindowTitle(id: state.windowId)
            }
        } else {
            // Different note — rename on disk directly
            var updated = note
            updated.updateTitle(trimmed)
            MacNoteStore.shared.saveNote(updated, originalFilename: note.filename)
            Task { await MacNoteStore.shared.loadAllNotes() }
        }

        renamingNoteId = nil
    }

    // MARK: - Delete

    private func deleteNote(_ note: Note) {
        let isActiveNote = note.id == state.note.id
        withAnimation(.smooth(duration: 0.3)) {
            MacNoteStore.shared.deleteNote(note)
        }
        if isActiveNote { state.resetToNewNote() }
    }
}

// MARK: - Sidebar Card

private struct NoteSidebarCard: View {
    let note: Note
    /// Whether this note is loaded in the editor (the "active" note).
    let isActive: Bool
    /// Whether the mouse is hovering over this card.
    let isHovered: Bool
    @Binding var isRenaming: Bool
    @Binding var renameText: String
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void
    let onHover: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isRenameFocused: Bool

    private let cardCornerRadius: CGFloat = 12

    private var cardFill: Color {
        colorScheme == .dark
            ? Color(red: 0.24, green: 0.24, blue: 0.25)
            : Color(nsColor: .textBackgroundColor)
    }

    /// Border color:
    /// - Hovered → subtle grey
    /// - Active → muted accent (always marks "loaded in editor")
    /// - Default → ultra-subtle structural border
    private var borderStroke: some ShapeStyle {
        if isActive {
            return AnyShapeStyle(Color.accentColor.opacity(0.45))
        }
        if isHovered {
            return AnyShapeStyle(
                colorScheme == .dark
                    ? Color.white.opacity(0.20)
                    : Color.black.opacity(0.18)
            )
        }
        return AnyShapeStyle(
            colorScheme == .dark
                ? Color.white.opacity(0.07)
                : Color.black.opacity(0.08)
        )
    }

    private var borderWidth: CGFloat {
        if isActive { return 2.0 }
        if isHovered { return 1.5 }
        return 0.5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            Text(note.title.isEmpty ? note.autoGeneratedTitle : note.title)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .popover(isPresented: $isRenaming, arrowEdge: .bottom) {
                    TextField("", text: $renameText)
                        .font(.system(size: 13, weight: .medium))
                        .textFieldStyle(.plain)
                        .focused($isRenameFocused)
                        .onSubmit { onCommitRename() }
                        .onExitCommand { onCancelRename() }
                        .frame(width: 220)
                        .padding(8)
                        .onAppear {
                            DispatchQueue.main.async {
                                isRenameFocused = true
                                DispatchQueue.main.async {
                                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                                }
                            }
                        }
                }

            // Content preview or cloud stub state
            if note.isCloudStub {
                VStack(spacing: 4) {
                    if note.isDownloading {
                        ProgressView().controlSize(.mini)
                        Text("Downloading…")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        Text(String(localized: "mac.sidebar.icloud", defaultValue: "Available in iCloud", comment: "Sidebar iCloud stub label"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(note.contentPreview(maxLines: 5))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Spacer(minLength: 0)

            // Tags
            let tags = Array(note.extractedTags.sorted().prefix(2))
            if !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.7))
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(.primary.opacity(0.06))
                            )
                    }
                    let remaining = note.extractedTags.count - 2
                    if remaining > 0 {
                        Text("+\(remaining)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(.primary.opacity(0.06))
                            )
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(cardFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(borderStroke, lineWidth: borderWidth)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .animation(.easeInOut(duration: 0.12), value: isActive)
        }
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06),
            radius: colorScheme == .dark ? 6 : 4,
            y: colorScheme == .dark ? 2 : 1
        )
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .onTapGesture { onSelect() }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { onDoubleClick() }
        )
        .onHover { hovering in
            onHover(hovering)
        }

    }
}
