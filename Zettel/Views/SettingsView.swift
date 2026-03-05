//
//  SettingsView.swift
//  Zettel
//
//  Created for Zettel project
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

struct SettingsView: View {
    @ObservedObject var noteStore: NoteStore
    @EnvironmentObject var themeStore: ThemeStore
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var dictationLocaleManager: DictationLocaleManager
    @EnvironmentObject var backgroundStore: BackgroundStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingFolderPicker = false
    @State private var showingTemplateInfo = false
    @State private var showingMacShareSheet = false
    
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
                
                // Background Section
                Section {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.iconTint)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.background".localized)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("settings.background_description".localized)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if backgroundStore.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                                .frame(height: 20)
                        } else {
                            PhotosPicker(
                                selection: $backgroundStore.selectedItem,
                                matching: .any(of: [.images, .videos]),
                                photoLibrary: .shared()
                            ) {
                                Text(backgroundStore.hasCustomBackground ?
                                     "settings.change".localized :
                                     "settings.choose".localized)
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    

                    
                    // Video Volume Slider - only show if background is video
                    if backgroundStore.backgroundType == .video {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "speaker.wave.2")
                                    .foregroundColor(.iconTint)
                                    .frame(width: 20)
                                Text("settings.video_volume".localized)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(Int(backgroundStore.videoVolume * 100))%")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            
                            Slider(
                                value: $backgroundStore.videoVolume,
                                in: 0.0...1.0
                            )
                            .accentColor(.iconTint)
                        }
                        .padding(.vertical, 4)
                    }

                    // Dimming Slider - only show if background is set
                    if backgroundStore.hasCustomBackground {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sun.min")
                                    .foregroundColor(.iconTint)
                                    .frame(width: 20)
                                Text("settings.background_dimming".localized)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(Int(backgroundStore.backgroundDimming * 100))%")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            
                            Slider(
                                value: $backgroundStore.backgroundDimming,
                                in: 0.0...0.8
                            )
                            .accentColor(.iconTint)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Loop Fade Duration Slider - only show if background is video
                    if backgroundStore.backgroundType == .video {
                         VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.iconTint)
                                    .frame(width: 20)
                                Text("settings.video_loop_fade_duration".localized)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(String(format: "%.1fs", backgroundStore.videoLoopFadeDuration))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                            }
                            
                            Slider(
                                value: $backgroundStore.videoLoopFadeDuration,
                                in: 0.0...5.0,
                                step: 0.1
                            )
                            .accentColor(.iconTint)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Loading indicator - Removed as it's now inline


                    // Remove button - only show if background is set
                    if backgroundStore.hasCustomBackground {
                        Button(role: .destructive) {
                            backgroundStore.removeBackground()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                Text("settings.remove_background".localized)
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("settings.background_section".localized)
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


                
                // App Info Section
                Section {
                    Button(action: {
                        showingMacShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "macbook")
                                .foregroundColor(.iconTint)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings.zettel_macos".localized)
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("settings.zettel_macos_description".localized)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 4)
                    .sheet(isPresented: $showingMacShareSheet) {
                        if let appStoreURL = URL(string: "https://apps.apple.com/app/id6748525244") {
                            ShareSheet(activityItems: [appStoreURL])
                        }
                    }
                    
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundColor(.iconTint)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.source_code".localized)
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
                
                // Debug Reset Section
                Section {
                    Button(role: .destructive, action: {
                        // Reset all stores
                        withAnimation {
                            themeStore.resetToDefaults()
                            backgroundStore.resetToDefaults()
                            dictationLocaleManager.resetToDefaults()
                            DefaultTitleTemplateManager.shared.saveTemplate("")
                            
                            // Reset NoteStore settings if any (none explicit so far besides storage which we probably shouldn't reset blindly)
                            // We purposefully DON'T reset storage location to avoid data loss confusion
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset All Settings")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                                
                                Text("Reverts theme, background, and other preferences to defaults")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 4)
                } header: {
                     Text("Debug - Reset")
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
        .alert(
            "Error",
            isPresented: Binding(
                get: { backgroundStore.errorMessage != nil },
                set: { if !$0 { backgroundStore.errorMessage = nil } }
            )
        ) {
            Button(StringConstants.Actions.ok.localized, role: .cancel) {
                backgroundStore.errorMessage = nil
            }
        } message: {
            if let errorMessage = backgroundStore.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(noteStore: NoteStore())
            .environmentObject(ThemeStore())
            .environmentObject(LocalizationManager.shared)
            .environmentObject(DictationLocaleManager.shared)
            .environmentObject(BackgroundStore())
    }
}
