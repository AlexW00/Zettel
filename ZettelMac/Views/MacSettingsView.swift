//
//  MacSettingsView.swift
//  ZettelMac
//
//  Settings window content for the macOS app.
//  Accessible via Cmd+, (standard macOS Settings scene).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ZettelKit

struct MacSettingsView: View {
    @State private var selectedAppearance: MacAppearanceOption = .fromUserDefaults()
    @Environment(\.openURL) private var openURL
    @State private var hideDockIcon = MacDockIconPreference.isHidden()
    @State private var isSyncingDockIconToggle = false
    @State private var fontSize: Double = EditorFontPreference.savedValue
    @State private var titleTemplate: String = DefaultTitleTemplateManager.shared.savedTemplate() ?? ""
    @State private var storageDirectory: URL = MacNoteStore.shared.storageDirectory
    @State private var showingFolderPicker = false
    @State private var showTemplateTokens = true

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                generalTab
            }

            Tab("About", systemImage: "info.circle") {
                aboutTab
            }
        }
        .frame(width: 450, height: 420)
        .onAppear {
            selectedAppearance = .fromUserDefaults()
            hideDockIcon = MacDockIconPreference.isHidden()
            fontSize = EditorFontPreference.savedValue
            titleTemplate = DefaultTitleTemplateManager.shared.savedTemplate() ?? ""
            storageDirectory = MacNoteStore.shared.storageDirectory
        }
        .onChange(of: selectedAppearance) { _, newValue in
            newValue.apply()
        }
        .onChange(of: hideDockIcon) { _, newValue in
            guard !isSyncingDockIconToggle else {
                isSyncingDockIconToggle = false
                return
            }

            guard MacDockIconPreference.apply(isHidden: newValue) else {
                isSyncingDockIconToggle = true
                hideDockIcon = MacDockIconPreference.isHidden()
                return
            }
        }
        .onChange(of: fontSize) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: EditorFontPreference.key)
        }
        .onChange(of: titleTemplate) { _, newValue in
            DefaultTitleTemplateManager.shared.saveTemplate(newValue)
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            // Appearance
            Picker("Appearance", selection: $selectedAppearance) {
                ForEach(MacAppearanceOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }

            Section {
                Toggle(
                    String(
                        localized: "settings.hideDockIcon.title",
                        defaultValue: "Hide Dock Icon",
                        comment: "Settings toggle label to hide the app's Dock icon on macOS."
                    ),
                    isOn: $hideDockIcon
                )
                Text(
                    String(
                        localized: "settings.hideDockIcon.explanation",
                        defaultValue: "Keeps Zettel out of the Dock and quits when all windows close.",
                        comment: "Explanation shown under the 'Hide Dock Icon' toggle in macOS Settings."
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Font Size
            LabeledContent {
                HStack(spacing: 8) {
                    Slider(
                        value: $fontSize,
                        in: EditorFontPreference.minSize...EditorFontPreference.maxSize,
                        step: 1
                    )
                    .frame(width: 160)
                    Text("\(Int(fontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            } label: {
                Text("Font Size")
            }

            // Storage
            LabeledContent {
                HStack(spacing: 8) {
                    Text(storageDirectory.abbreviatedPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(storageDirectory.path)

                    Button("Change…") {
                        showingFolderPicker = true
                    }
                    .fixedSize()
                    .layoutPriority(1)
                }
            } label: {
                Text("Storage Location")
            }

            // Title Template
            Section {
                LabeledContent {
                    TextField("", text: $titleTemplate, prompt: Text(DefaultTitleTemplateManager.shared.fallbackTemplate).foregroundStyle(.tertiary))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                } label: {
                    Text("Default Title")
                }

                DisclosureGroup("Title Variables", isExpanded: $showTemplateTokens) {
                    let examples = DefaultTitleTemplateManager.shared.placeholderExamples()
                    Grid(alignment: .leading, verticalSpacing: 4) {
                        ForEach(examples, id: \.token) { example in
                            GridRow {
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
                    .padding(.vertical, 2)
                }
                .font(.callout)
            }
            #if DEBUG
            Section("Debug") {
                Button("Reset Welcome Note") {
                    UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
                }
                .foregroundStyle(.orange)
            }
            #endif
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

            Text("A minimal note-taking app.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                // Zettel for iOS
                ShareLink(item: URL(string: "https://apps.apple.com/app/id6748525244")!) {
                    HStack {
                        Image(systemName: "iphone")
                            .frame(width: 20)
                        Text("Zettel for iOS")
                            .font(.callout)
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Divider()

                // More Apps
                Button(action: {
                    if let url = URL(string: "https://apps.weichart.de") {
                        openURL(url)
                    }
                }) {
                    HStack {
                        Image("WeichartApps")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        Text("More Apps")
                            .font(.callout)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Divider()

                // GitHub
                Button(action: {
                    if let url = URL(string: "https://github.com/AlexW00/Zettel") {
                        openURL(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .frame(width: 20)
                        Text("Source Code")
                            .font(.callout)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Divider()

                // Developer
                Button(action: {
                    if let url = URL(string: "https://x.com/AlexWeichart") {
                        openURL(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "person.circle")
                            .frame(width: 20)
                        Text("Developer")
                            .font(.callout)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - URL Helpers

private extension URL {
    /// Returns an abbreviated path replacing the home directory with ~
    var abbreviatedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let full = self.path
        if full.hasPrefix(home) {
            return "~" + full.dropFirst(home.count)
        }
        return full
    }
}

enum MacAppearanceOption: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "selectedTheme"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    @MainActor
    func apply() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
        NSApplication.shared.appearance = nsAppearance
    }

    static func fromUserDefaults() -> Self {
        let savedValue = UserDefaults.standard.string(forKey: storageKey) ?? Self.system.rawValue
        return Self(rawValue: savedValue) ?? .system
    }
}

