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
    
    /// The font size for content text, automatically saved to UserDefaults
    @Published var contentFontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(contentFontSize, forKey: "contentFontSize")
        }
    }
    
    /**
     * Initializes the theme store with the previously saved theme preference.
     * Defaults to system theme if no preference is found.
     */
    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.system.rawValue
        self.currentTheme = AppTheme(rawValue: savedTheme) ?? .system
        
        let savedFontSize = UserDefaults.standard.object(forKey: "contentFontSize") as? CGFloat
        self.contentFontSize = savedFontSize ?? LayoutConstants.FontSize.large
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
                return UIColor.white
            }
        })
    }

    static var overviewBackground: Color {
        Color(UIColor.systemGroupedBackground)
    }
    
    static var tagBackground: Color {
        Color(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor.secondarySystemBackground.withAlphaComponent(0.65)
            } else {
                return UIColor.white
            }
        })
    }

    static var dictationIdleForeground: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 1.0, alpha: 0.92)
            } else {
                return UIColor.label.withAlphaComponent(0.85)
            }
        })
    }

    static var dictationBusyForeground: Color {
        Color(UIColor.secondaryLabel)
    }

    static var dictationRecordingForeground: Color {
        Color(UIColor { trait in
            let base = UIColor.systemRed
            if trait.userInterfaceStyle == .dark {
                return base.withAlphaComponent(0.95)
            } else {
                return base.withAlphaComponent(0.8)
            }
        })
    }

    static var dictationBackgroundTint: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 0.18, alpha: 0.32)
            } else {
                return UIColor(white: 0.0, alpha: 0.08)
            }
        })
    }
}
