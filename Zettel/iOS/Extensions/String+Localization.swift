//
//  String+Localization.swift
//  Zettel
//
//  Created by GitHub Copilot on 08.07.25.
//
//  String extensions for localization support.
//

import Foundation
import SwiftUI

extension String {
    /// Returns the localized string for the given key
    var localized: String {
        // Use the LocalizationManager to get the correct localized string
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    /// Returns the localized string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments)
    }
}

/// SwiftUI View modifier that makes localized text reactive to language changes
struct LocalizedText: View {
    private let key: String
    private let arguments: [CVarArg]
    @StateObject private var localizationManager = LocalizationManager.shared
    
    init(_ key: String, arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }
    
    var body: some View {
        Text(localizedString)
            .id(localizationManager.languageUpdateId) // Force refresh when language changes
    }
    
    private var localizedString: String {
        // Force dependency on language update ID
        _ = localizationManager.languageUpdateId
        
        if arguments.isEmpty {
            return key.localized
        } else {
            return String(format: key.localized, arguments: arguments)
        }
    }
}

/// A reactive localized string value that updates when language changes
@propertyWrapper
struct LocalizedString: DynamicProperty {
    private let key: String
    private let arguments: [CVarArg]
    @StateObject private var localizationManager = LocalizationManager.shared
    
    init(_ key: String, arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }
    
    var wrappedValue: String {
        // The dependency on localizationManager.languageUpdateId ensures this recomputes
        _ = localizationManager.languageUpdateId
        
        if arguments.isEmpty {
            return key.localized
        } else {
            return String(format: key.localized, arguments: arguments)
        }
    }
}

/// View modifier that makes any view reactive to language changes
struct LanguageAware: ViewModifier {
    @StateObject private var localizationManager = LocalizationManager.shared
    
    func body(content: Content) -> some View {
        content
            .id(localizationManager.languageUpdateId)
    }
}

extension View {
    /// Makes this view reactive to language changes
    func languageAware() -> some View {
        modifier(LanguageAware())
    }
}
