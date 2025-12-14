//
//  NotesListPopoverView.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import SwiftUI
import os.log

struct NotesListPopoverView: View {
    @EnvironmentObject private var notesStore: NotesStore
    let activeNoteURL: URL?
    let onOpen: (NotesStore.NoteSummary) -> Void
    let onOpenInNewWindow: (NotesStore.NoteSummary) -> Void

    @State private var filter = ""
    @State private var hoveredNoteID: NotesStore.NoteSummary.ID?
    @AppStorage("NotesListPopover.skipDeleteConfirm") private var skipDeleteConfirm = false
    @State private var notePendingDeletion: NotesStore.NoteSummary?
    @State private var showDeleteConfirmation = false
    @State private var dontAskAgainChoice = false
    private let logger = Logger(subsystem: "zettel-desktop", category: "NotesListPopover")

    private var filteredNotes: [NotesStore.NoteSummary] {
        let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return notesStore.notes }
        return notesStore.notes.filter { summary in
            summary.title.localizedCaseInsensitiveContains(trimmed)
            || summary.preview.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Filter notes…", text: $filter)
                    .textFieldStyle(.roundedBorder)

                if filteredNotes.isEmpty {
                    VStack(alignment: .center, spacing: 8) {
                        Text("No notes found")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("Create a new note with the + button.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredNotes) { note in
                                NotesListRow(
                                    note: note,
                                    isHovered: hoveredNoteID == note.id,
                                    isActive: note.url == activeNoteURL,
                                    onHoverChange: { hovering in
                                        updateHoverState(for: note, hovering: hovering)
                                    },
                                    onOpen: {
                                        logger.info("List tap title=\(note.title, privacy: .public)")
                                        onOpen(note)
                                    },
                                    onDelete: {
                                        requestDeletion(of: note)
                                    }
                                )
                                .contextMenu {
                                    Button("Open in New Window") {
                                        onOpenInNewWindow(note)
                                    }
                                }
                            }
                        }
                        .padding(.trailing, 12)
                    }
                    .frame(maxHeight: 240)
                }
            }
            .padding(14)
            .frame(width: 280)

            if showDeleteConfirmation, let pending = notePendingDeletion {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                DeleteConfirmationCard(
                    noteTitle: pending.title,
                    dontAskAgain: $dontAskAgainChoice,
                    onConfirm: { confirmDelete(skipFuturePrompts: dontAskAgainChoice) },
                    onCancel: {
                        notePendingDeletion = nil
                        showDeleteConfirmation = false
                    }
                )
                .frame(maxWidth: 260)
            }
        }
    }

    private func updateHoverState(for note: NotesStore.NoteSummary, hovering: Bool) {
        if hovering {
            hoveredNoteID = note.id
        } else if hoveredNoteID == note.id {
            hoveredNoteID = nil
        }
    }

    private func requestDeletion(of note: NotesStore.NoteSummary) {
        guard skipDeleteConfirm == false else {
            confirmDelete(note: note, skipFuturePrompts: false)
            return
        }
        notePendingDeletion = note
        showDeleteConfirmation = true
        dontAskAgainChoice = false
    }

    private func confirmDelete(skipFuturePrompts: Bool) {
        guard let note = notePendingDeletion else { return }
        confirmDelete(note: note, skipFuturePrompts: skipFuturePrompts)
    }

    private func confirmDelete(note: NotesStore.NoteSummary, skipFuturePrompts: Bool) {
        if skipFuturePrompts {
            skipDeleteConfirm = true
        }
        delete(note)
    }

    private func delete(_ note: NotesStore.NoteSummary) {
        do {
            try notesStore.deleteNote(note)
            if hoveredNoteID == note.id {
                hoveredNoteID = nil
            }
            if notePendingDeletion?.id == note.id {
                notePendingDeletion = nil
                showDeleteConfirmation = false
            }
        } catch {
            logger.error("Failed to delete note=\(note.title, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }
    }
}


private struct NotesListRow: View {
    let note: NotesStore.NoteSummary
    let isHovered: Bool
    let isActive: Bool
    let onHoverChange: (Bool) -> Void
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(note.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                Spacer(minLength: 6)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Delete Note")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(borderColor, lineWidth: 0.8)
                )
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onHover(perform: onHoverChange)
    }

    private var backgroundColor: Color {
        if isActive {
            return Color.accentColor.opacity(isHovered ? 0.2 : 0.12)
        }
        if isHovered {
            return Color.primary.opacity(0.08)
        }
        return Color.clear
    }

    private var borderColor: Color {
        isActive ? Color.accentColor.opacity(0.45) : Color.clear
    }
}

private struct DeleteConfirmationCard: View {
    let noteTitle: String
    @Binding var dontAskAgain: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delete \"\(noteTitle)\"?")
                .font(.headline)
            Text("This removes the file from disk.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Toggle("Do not ask again", isOn: $dontAskAgain)
                .toggleStyle(.checkbox)
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Delete", role: .destructive, action: onConfirm)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1))
        )
        .padding(.horizontal, 10)
    }
}

#if DEBUG
struct NotesListPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        let store = NotesStore.shared
        return NotesListPopoverView(
            activeNoteURL: nil,
            onOpen: { _ in },
            onOpenInNewWindow: { _ in }
        )
        .environmentObject(store)
    }
}
#endif
