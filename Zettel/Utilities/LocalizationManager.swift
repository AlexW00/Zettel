//
//  LocalizationManager.swift
//  Zettel
//
//  Created by GitHub Copilot on 02.08.25.
//
//  Manages localization updates when the app language changes.
//

import Foundation
import SwiftUI

/// Observable class that tracks language changes and forces UI updates
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    /// Published property that changes when the language changes, forcing UI updates
    @Published var languageUpdateId = UUID()
    
    /// Current language code for debugging
    @Published var currentLanguage: String = ""
    
    /// The bundle to use for localization
    private var localizationBundle: Bundle = Bundle.main
    
    private init() {
        // Set initial language and bundle
        updateLanguageAndBundle()
        
        // Listen for locale changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localeDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
        
        // Listen for app becoming active (when user returns from Settings)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Listen for language changes specifically
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: NSNotification.Name("AppleLanguagePreferencesChangedNotification"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateLanguageAndBundle() {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        currentLanguage = preferredLanguage
        
        // Extract the language code (e.g., "de" from "de-DE")
        let languageCode = String(preferredLanguage.prefix(2))
        
        // Try to find a bundle for the current language
        if let bundlePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: bundlePath) {
            localizationBundle = bundle
            print("🌍 Using localization bundle for language: \(languageCode)")
        } else {
            // Fallback to main bundle (English)
            localizationBundle = Bundle.main
            print("🌍 Fallback to main bundle for language: \(languageCode)")
        }
        
        print("🌍 Current language: \(currentLanguage) -> \(languageCode)")
    }
    
    @objc private func localeDidChange() {
        print("🌍 Locale did change notification received")
        updateLanguage()
    }
    
    @objc private func appDidBecomeActive() {
        print("🌍 App became active - checking for language changes")
        let oldLanguage = currentLanguage
        updateLanguageAndBundle()
        
        if oldLanguage != currentLanguage {
            print("🌍 Language changed from \(oldLanguage) to \(currentLanguage)")
            updateLanguage()
        }
    }
    
    @objc private func languageDidChange() {
        print("🌍 Language preferences changed notification received")
        updateLanguage()
    }
    
    private func updateLanguage() {
        DispatchQueue.main.async {
            self.updateLanguageAndBundle()
            self.languageUpdateId = UUID()
            print("🌍 UI update triggered with new ID: \(self.languageUpdateId)")
        }
    }
    
    /// Get localized string using the correct bundle
    func localizedString(for key: String, comment: String = "") -> String {
        let localizedString = localizationBundle.localizedString(forKey: key, value: nil, table: nil)
        
        // If the key wasn't found in the specific bundle, try the main bundle
        if localizedString == key {
            let fallbackString = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
            print("⚠️ Using fallback localization for '\(key)': '\(fallbackString)'")
            return fallbackString
        }
        
        print("✅ Localized '\(key)' -> '\(localizedString)'")
        return localizedString
    }
    
    /// Force a language update (useful for testing or manual refresh)
    func forceUpdate() {
        print("🌍 Force update requested")
        updateLanguage()
    }
}
