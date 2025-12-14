//
//  SettingsRootView.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import SwiftUI
import AppKit

struct SettingsRootView: View {
    @EnvironmentObject private var notesStore: NotesStore

    @State private var showingFolderPicker = false
    @State private var folderPathDescription: String = ""

    var body: some View {
        Form {
            Section("Notes Folder") {
                HStack {
                    Text(folderDescription)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    Button("Choose…") { chooseFolder() }
                    Button("Reveal") { revealFolder() }
                        .disabled(notesStore.folderURL == nil)
                    Button("Clear") { notesStore.setFolderURL(nil) }
                        .disabled(notesStore.folderURL == nil)
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: $notesStore.themePreference) {
                    ForEach(NotesStore.ThemePreference.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Default Title Template") {
                TextField("Template", text: $notesStore.titleTemplate)
                Text("Use {{date}} and {{time}} placeholders. {{title}} inserts the first line.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Global Shortcut") {
                HStack {
                    Text("⌃⌥⌘N")
                    Spacer()
                    Text("Change shortcut in a future update")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var folderDescription: String {
        if let url = notesStore.folderURL {
            return url.path
        }
        return "No folder selected"
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Choose"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            notesStore.setFolderURL(url)
        }
    }

    private func revealFolder() {
        guard let url = notesStore.folderURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
