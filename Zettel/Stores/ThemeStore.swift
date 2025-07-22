//
//  ThemeStore.swift
//  Zettel
//
//  Created for Zettel project
//
//  Theme management for the application, handling light/dark mode switching
//  and user preferences persistence.
//

import SwiftUI
import Foundation

/**
 * Represents the available theme options for the application.
 * 
 * Supports system-based theme switching as well as explicit light/dark modes.
 */
enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "theme.system".localized
        case .light: return "theme.light".localized
        case .dark: return "theme.dark".localized
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/**
 * Manages theme preferences for the application.
 * 
 * Handles theme selection, persistence, and provides reactive updates
 * when the theme changes.
 */
@MainActor
class ThemeStore: ObservableObject {
    /// The currently selected theme, automatically saved to UserDefaults
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    /**
     * Initializes the theme store with the previously saved theme preference.
     * Defaults to system theme if no preference is found.
     */
    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.system.rawValue
        self.currentTheme = AppTheme(rawValue: savedTheme) ?? .system
    }
}

// MARK: - Theme Colors
extension Color {
    // Background colors
    static var appBackground: Color {
        Color(UIColor.systemGroupedBackground)
    }
    
    static var primaryBackground: Color {
        Color(UIColor.systemBackground)
    }
    
    static var cardBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
    
    static var groupedBackground: Color {
        Color(UIColor.systemGroupedBackground)
    }
    
    // Text colors
    static var primaryText: Color {
        Color(UIColor.label)
    }
    
    static var secondaryText: Color {
        Color(UIColor.secondaryLabel)
    }
    
    static var tertiaryText: Color {
        Color(UIColor.tertiaryLabel)
    }
    
    // UI element colors
    static var separator: Color {
        Color(UIColor.separator)
    }
    
    static var buttonTint: Color {
        Color(UIColor.tintColor)
    }
    
    // Shadow colors
    static var cardShadow: Color {
        Color(UIColor.label).opacity(0.08)
    }
    
    // Custom app colors that adapt to dark mode
    static var tearIndicator: Color {
        Color(UIColor.systemGray)
    }
    
    static var tearIndicatorActive: Color {
        Color(UIColor.systemGreen)
    }
    
    // Note-specific colors
    static var noteBackground: Color {
        Color(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor.secondarySystemBackground
            } else {
                return UIColor.systemBackground // Pure white in light mode
            }
        })
    }
    
    static var overviewBackground: Color {
        Color(UIColor.systemGroupedBackground)
    }
}
