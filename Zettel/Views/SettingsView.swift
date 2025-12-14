//
//  SettingsView.swift
//  Zettel
//
//  Created for Zettel project
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var noteStore: NoteStore
    @EnvironmentObject var themeStore: ThemeStore
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var dictationLocaleManager: DictationLocaleManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingFolderPicker = false
    @State private var showingTemplateInfo = false
    
    private var templateInfoMessage: String {
        let manager = DefaultTitleTemplateManager.shared
        let examples = manager.placeholderExamples()
        let fallback = manager.fallbackTemplate
        let format = StringConstants.Settings.defaultTitleTemplateInfoMessage.localized
        let exampleList = examples
            .map { "- \($0.token): \($0.example)" }
            .joined(separator: "\n")
        return String(format: format, exampleList, fallback)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Theme Section
                Section {
                    HStack {
                        Image(systemName: "paintbrush")
                            .foregroundColor(.iconTint)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.appearance".localized)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("settings.theme_description".localized)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Menu {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        themeStore.currentTheme = theme
                                    }
                                }) {
                                    HStack {
                                        Text(theme.displayName)
                                        if themeStore.currentTheme == theme {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(themeStore.currentTheme.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Font Size Slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "textformat.size")
                                .foregroundColor(.iconTint)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(StringConstants.Settings.fontSize.localized)
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text(StringConstants.Settings.fontSizeDescription.localized)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(Int(themeStore.contentFontSize))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("settings.font_size_small_label".localized)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Slider(
                                value: $themeStore.contentFontSize,
                                in: LayoutConstants.FontSize.contentMinSize...LayoutConstants.FontSize.contentMaxSize,
                                step: 1
                            )
                            .accentColor(.iconTint)
                            
                            Text("settings.font_size_large_label".localized)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 32) // Align with icon
                    }
                    .padding(.vertical, 4)

                    // Default Title Template
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Image(systemName: "textformat.alt")
                                .foregroundColor(.iconTint)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(StringConstants.Settings.defaultTitleTemplate.localized)
                                        .font(.system(size: 16, weight: .medium))

                                    Button(action: {
                                        showingTemplateInfo = true
                                    }) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .accessibilityLabel(Text(StringConstants.Settings.defaultTitleTemplateInfoButton.localized))
                                }

                                Text(StringConstants.Settings.defaultTitleTemplateDescription.localized)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }

                        TextField(
                            StringConstants.Settings.defaultTitleTemplatePlaceholder.localized,
                            text: $noteStore.defaultTitleTemplate
                        )
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .padding(.leading, 32)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("settings.display".localized)
                }
                
                // Dictation Locale Selection
                Section {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "mic.circle")
                            .foregroundColor(.iconTint)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(StringConstants.Settings.dictationSection.localized)
                                .font(.system(size: 16, weight: .medium))

                            Text(StringConstants.Settings.dictationSectionDescription.localized)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        if dictationLocaleManager.isLoadingLocales {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.iconTint)
                                .frame(width: 24, height: 24)
                                .accessibilityLabel(Text(StringConstants.Settings.dictationLocaleMenuLoading.localized))
                        } else if let currentOption = dictationLocaleManager.localeOption() {
                            Menu {
                                ForEach(dictationLocaleManager.localeOptions) { option in
                                    Button {
                                        dictationLocaleManager.updateSelectedLocale(option)
                                    } label: {
                                        HStack {
                                            Text(option.displayName)
                                            Spacer()
                                            Text(option.isInstalled ? StringConstants.Dictation.localeCellInstalled.localized : StringConstants.Dictation.localeCellPending.localized)
                                                .font(.system(size: 12))
                                                .foregroundColor(option.isInstalled ? .secondary : .orange)
                                            if dictationLocaleManager.selectedLocaleIdentifier == option.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(currentOption.displayName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(UIColor.secondarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        } else {
                            Text("--")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                header: {
                    Text(StringConstants.Settings.dictationSection.localized)
                } footer: {
                    Text(StringConstants.Settings.dictationSectionDescription.localized)
                }

                // Storage Section
                Section {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.iconTint)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.storage_location".localized)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(noteStore.storageDirectory.path)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        Button(StringConstants.Actions.change.localized) {
                            showingFolderPicker = true
                        }
                        .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(StringConstants.Navigation.storage.localized)
                } footer: {
                    Text("settings.storage_description".localized)
                }
                
                // App Info Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.iconTint)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.app_name".localized)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(StringConstants.Settings.viewOnGitHub.localized)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if let url = URL(string: "https://github.com/AlexW00/Zettel") {
                                openURL(url)
                            }
                        }) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.iconTint)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(StringConstants.Settings.developer.localized)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(StringConstants.Settings.developerDescription.localized)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if let url = URL(string: "https://x.com/AlexWeichart") {
                                openURL(url)
                            }
                        }) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(StringConstants.Navigation.about.localized)
                }
                
                #if DEBUG
                // Debug Section - only visible in debug builds
                Section {
                    Button(action: {
                        // Set last seen version to 1.0 to simulate an update from an older version
                        ChangelogManager.shared.setDebugLastSeenVersion(AppVersion(major: 1, minor: 0))
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.iconTint)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Simulate Update from v1.0")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Shows changelog on next app launch")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 4)
                } header: {
                    Text("Debug")
                }
                #endif
            }
            .navigationTitle(StringConstants.Navigation.settings.localized)
            .navigationBarTitleDisplayMode(.inline)
            .languageAware() // Make the entire navigation reactive to language changes
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(StringConstants.Actions.done.localized) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                }
            }
            .task {
                await dictationLocaleManager.loadLocalesIfNeeded()
            }
        }
        .preferredColorScheme(themeStore.currentTheme.colorScheme)
        .alert(
            StringConstants.Settings.defaultTitleTemplateInfoTitle.localized,
            isPresented: $showingTemplateInfo
        ) {
            Button(StringConstants.Actions.ok.localized, role: .cancel) { }
        } message: {
            Text(templateInfoMessage)
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // The fileImporter already handles security scoping
                    noteStore.updateStorageDirectory(url)
                }
            case .failure(let error):
                print("Error selecting folder: \(error)")
            }
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(noteStore: NoteStore())
            .environmentObject(ThemeStore())
            .environmentObject(LocalizationManager.shared)
            .environmentObject(DictationLocaleManager.shared)
    }
}
