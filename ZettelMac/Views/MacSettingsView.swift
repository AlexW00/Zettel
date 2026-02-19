//
//  MacSettingsView.swift
//  ZettelMac
//
//  Settings window content for the macOS app.
//  Accessible via Cmd+, (standard macOS Settings scene).
//

import SwiftUI
import ZettelKit

struct MacSettingsView: View {
    @State private var fontSize: Double = UserDefaults.standard.double(forKey: "editorFontSize").clamped(to: 12...28, fallback: 15)
    @State private var titleTemplate: String = DefaultTitleTemplateManager.shared.currentTemplate()
    @State private var storageDirectory: URL = MacNoteStore.shared.storageDirectory
    @State private var showingFolderPicker = false

    var body: some View {
        TabView {
            Tab(String(localized: "General", comment: "Settings tab"), systemImage: "gearshape") {
                generalTab
            }

            Tab(String(localized: "About", comment: "Settings tab"), systemImage: "info.circle") {
                aboutTab
            }
        }
        .frame(width: 440, height: 320)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            // Font size
            LabeledContent {
                HStack {
                    Slider(value: $fontSize, in: 12...28, step: 1)
                        .frame(width: 160)
                    Text("\(Int(fontSize))pt")
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            } label: {
                Label(String(localized: "Font Size", comment: "Settings label"), systemImage: "textformat.size")
            }
            .onChange(of: fontSize) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "editorFontSize")
            }

            // Title template
            LabeledContent {
                TextField(
                    DefaultTitleTemplateManager.shared.fallbackTemplate,
                    text: $titleTemplate
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            } label: {
                Label(String(localized: "Title Template", comment: "Settings label"), systemImage: "character.cursor.ibeam")
            }
            .onChange(of: titleTemplate) { _, newValue in
                DefaultTitleTemplateManager.shared.saveTemplate(newValue)
            }

            // Template tokens help
            DisclosureGroup(String(localized: "Template Tokens", comment: "Settings disclosure")) {
                let examples = DefaultTitleTemplateManager.shared.placeholderExamples()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(examples, id: \.token) { example in
                        HStack {
                            Text(example.token)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                            Text("→")
                                .foregroundStyle(.tertiary)
                            Text(example.example)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .font(.caption)

            Divider()

            // Storage location
            LabeledContent {
                HStack(spacing: 8) {
                    Text(storageDirectory.lastPathComponent)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button(String(localized: "Change…", comment: "Settings button")) {
                        showingFolderPicker = true
                    }
                }
            } label: {
                Label(String(localized: "Storage Location", comment: "Settings label"), systemImage: "folder")
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                storageDirectory = url
                MacNoteStore.shared.updateStorageDirectory(url)
            }
        }
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Zettel")
                .font(.title2.bold())

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("Version \(version) (\(build))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(String(localized: "A minimal note-taking app.", comment: "About description"))
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>, fallback: Double) -> Double {
        if self == 0 { return fallback }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
