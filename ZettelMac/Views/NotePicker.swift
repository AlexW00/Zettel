//
//  NotePicker.swift
//  ZettelMac
//
//  Liquid glass modal for browsing and opening notes.
//  Click = open in current window. Cmd+Click = open in new window.
//  Hovered rows show a delete button.
//

import AppKit
import SwiftUI
import ZettelKit

// MARK: - Note Picker Modal (centered overlay)

/// Full-window overlay with a centered liquid glass note picker.
struct NotePickerModal: View {
    @Bindable var state: ZettelWindowState

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private let pickerPreferredWidth: CGFloat = 420
    private let pickerPreferredHeight: CGFloat = 320
    private let pickerMinWindowMargin: CGFloat = 20

    private var store: MacNoteStore { MacNoteStore.shared }

    private var filteredNotes: [Note] {
        let notes = store.allNotes
        let filtered: [Note]

        if searchText.isEmpty {
            filtered = notes
        } else {
            filtered = notes.filter { note in
                note.title.localizedStandardContains(searchText)
                || note.content.localizedStandardContains(searchText)
            }
        }

        return filtered.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Transparent backdrop — click to dismiss
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        state.isShowingPicker = false
                    }

                // Centered modal panel
                VStack(spacing: 0) {
                    searchField
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 10)

                    Divider()
                        .padding(.horizontal, 12)

                    if store.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredNotes.isEmpty {
                        emptyState
                    } else {
                        notesList
                    }
                }
                .frame(
                    width: min(pickerPreferredWidth, max(0, geometry.size.width - (pickerMinWindowMargin * 2))),
                    height: min(pickerPreferredHeight, max(0, geometry.size.height - (pickerMinWindowMargin * 2)))
                )
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await store.loadAllNotes()
        }
        .onAppear {
            focusSearchField()
        }
        .onChange(of: store.isLoading) { _, isLoading in
            if !isLoading {
                focusSearchField()
            }
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
                .font(.system(size: 13))

            TextField(
                String(
                    localized: "mac.picker.filter_placeholder",
                    defaultValue: "Search for notes…",
                    comment: "Picker search placeholder"
                ),
                text: $searchText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .focused($isSearchFocused)

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
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - Notes List

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredNotes, id: \.id) { note in
                    NotePickerRow(
                        note: note,
                        isCurrent: note.id == state.note.id,
                        onOpen: { openNoteFromClick(note) },
                        onDelete: { deleteNote(note) }
                    )
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty
                 ? String(localized: "mac.picker.empty", defaultValue: "No notes yet", comment: "Picker empty state")
                 : String(localized: "mac.picker.no_results", defaultValue: "No matching notes", comment: "Picker no results"))
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func openNoteFromClick(_ note: Note) {
        let openInNewWindow = NSApp.currentEvent?.modifierFlags.contains(.command) == true
        openNote(note, inNewWindow: openInNewWindow)
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

    private func focusSearchField() {
        Task { @MainActor in
            await Task.yield()
            isSearchFocused = true
        }
    }
}

// MARK: - Note Picker Row

private struct NotePickerRow: View {
    let note: Note
    let isCurrent: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private var shouldFadeSubtitle: Bool {
        note.contentPreview.count > 42
    }

    private var subtitle: String {
        return note.contentPreview
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(note.title.isEmpty ? note.autoGeneratedTitle : note.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .mask {
                            if shouldFadeSubtitle {
                                HStack(spacing: 0) {
                                    Color.black
                                    LinearGradient(
                                        colors: [.black, .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .frame(width: 40)
                                }
                            } else {
                                Color.black
                            }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help(String(localized: "mac.picker.delete_note", defaultValue: "Delete Note", comment: "Picker row delete action"))
                .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovering ? Color.accentColor.opacity(0.12) : (isCurrent ? Color.gray.opacity(0.22) : .clear))
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
