//
//  CommandPaletteView.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import SwiftUI
import AppKit
import Carbon

struct CommandPaletteView: View {
    let notes: [NotesStore.NoteSummary]
    let onOpen: (NotesStore.NoteSummary) -> Void
    let onOpenInNewWindow: (NotesStore.NoteSummary) -> Void
    let onDismiss: () -> Void

    @Binding var query: String
    @State private var selectionID: UUID?
    @FocusState private var isSearchFocused: Bool
    @State private var eventMonitor: Any?

    private var filteredNotes: [NotesStore.NoteSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return notes }
        return notes.filter { summary in
            summary.title.localizedCaseInsensitiveContains(trimmed)
            || summary.accessoryDescription.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Search for notes…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFocused)
                    .onSubmit { triggerOpen(inNewWindow: false) }
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Palette")
            }

            if filteredNotes.isEmpty {
                Text("No matching notes")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredNotes) { note in
                            CommandPaletteRow(note: note, isSelected: note.id == selectionID)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    onOpen(note)
                                }
                                .onTapGesture(count: 1) {
                                    selectionID = note.id
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: min(280, CGFloat(filteredNotes.count) * 52))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear {
            isSearchFocused = true
            if selectionID == nil {
                selectionID = filteredNotes.first?.id
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == kVK_Escape {
                    onDismiss()
                    return nil
                }
                if event.keyCode == kVK_Return || event.keyCode == kVK_ANSI_KeypadEnter {
                    if event.modifierFlags.contains(.command) {
                        triggerOpen(inNewWindow: true)
                    } else {
                        triggerOpen(inNewWindow: false)
                    }
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
        }
        .onChange(of: filteredNotes.map { $0.id }) { newIDs in
            guard !newIDs.isEmpty else {
                selectionID = nil
                return
            }
            guard let current = selectionID else {
                selectionID = newIDs.first
                return
            }
            if newIDs.contains(current) == false {
                selectionID = newIDs.first
            }
        }
    }

    private func triggerOpen(inNewWindow: Bool) {
        guard let note = resolvedSelection else { return }
        if inNewWindow {
            onOpenInNewWindow(note)
        } else {
            onOpen(note)
        }
    }

    private var resolvedSelection: NotesStore.NoteSummary? {
        if let selectionID, let selected = filteredNotes.first(where: { $0.id == selectionID }) {
            return selected
        }
        return filteredNotes.first
    }
}

private struct CommandPaletteRow: View {
    let note: NotesStore.NoteSummary
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(note.title)
                    .font(.headline)
                Spacer()
            }
            Text(note.accessoryDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
    }
}
