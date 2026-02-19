//
//  NotePicker.swift
//  ZettelMac
//
//  In-window search overlay for browsing and opening notes.
//  Cmd+Enter or Cmd+Click opens in a new window.
//

import SwiftUI
import ZettelKit

struct NotePicker: View {
    @Bindable var state: ZettelWindowState

    @State private var searchText = ""
    @State private var selectedIndex: Int = 0

    private var store: MacNoteStore { MacNoteStore.shared }

    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return store.allNotes
        }
        let query = searchText.lowercased()
        return store.allNotes.filter { note in
            note.title.lowercased().contains(query)
            || note.content.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            searchField

            Divider().opacity(0.5)

            // Notes list
            if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredNotes.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .task {
            await store.loadAllNotes()
        }
        .onKeyPress(.escape) {
            state.isShowingPicker = false
            return .handled
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))

            TextField(
                String(localized: "Search notes…", comment: "Picker search placeholder"),
                text: $searchText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .onSubmit {
                openSelectedNote(inNewWindow: false)
            }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Notes List

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { index, note in
                    NotePickerRow(
                        note: note,
                        isSelected: index == selectedIndex,
                        onOpen: { openNote(note, inNewWindow: false) },
                        onOpenNewWindow: { openNote(note, inNewWindow: true) },
                        onDelete: { deleteNote(note) }
                    )
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .onChange(of: filteredNotes.count) {
            selectedIndex = min(selectedIndex, max(filteredNotes.count - 1, 0))
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(selectedIndex + 1, filteredNotes.count - 1)
            return .handled
        }
        .onKeyPress(.return, phases: .down) { press in
            if press.modifiers.contains(.command) {
                openSelectedNote(inNewWindow: true)
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty
                 ? String(localized: "No notes yet", comment: "Picker empty state")
                 : String(localized: "No matching notes", comment: "Picker no results"))
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func openSelectedNote(inNewWindow: Bool) {
        guard !filteredNotes.isEmpty, filteredNotes.indices.contains(selectedIndex) else { return }
        openNote(filteredNotes[selectedIndex], inNewWindow: inNewWindow)
    }

    private func openNote(_ note: Note, inNewWindow: Bool) {
        if inNewWindow {
            ZettelWindowManager.shared.createWindow(note: note)
        } else {
            state.loadNote(note)
        }
        state.isShowingPicker = false
    }

    private func deleteNote(_ note: Note) {
        MacNoteStore.shared.deleteNote(note)
    }
}

// MARK: - Note Picker Row

private struct NotePickerRow: View {
    let note: Note
    let isSelected: Bool
    let onOpen: () -> Void
    let onOpenNewWindow: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title.isEmpty ? note.autoGeneratedTitle : note.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !note.contentPreview.isEmpty {
                    Text(note.contentPreview)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // Timestamp
            Text(note.modifiedAt, style: .relative)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            // Action buttons (visible on hover)
            if isHovering {
                HStack(spacing: 4) {
                    Button {
                        onOpenNewWindow()
                    } label: {
                        Image(systemName: "rectangle.on.rectangle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Open in New Window", comment: "Picker row action"))

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Delete Note", comment: "Picker row action"))
                }
                .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected || isHovering ? Color.accentColor.opacity(0.12) : .clear)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
