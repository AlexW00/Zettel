//
//  SettingsView.swift
//  Zettel
//
//  Created for Zettel project
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var noteStore: NoteStore
    @EnvironmentObject var themeStore: ThemeStore
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingFolderPicker = false
    
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
                } header: {
                    Text("settings.display".localized)
                } footer: {
                    Text("settings.system_description".localized)
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
        }
        .preferredColorScheme(themeStore.currentTheme.colorScheme)
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
    }
}
