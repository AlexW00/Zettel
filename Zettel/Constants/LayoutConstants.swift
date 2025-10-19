//
//  LayoutConstants.swift
//  Zettel
//
//  Created by GitHub Copilot on 08.07.25.
//

import Foundation
import SwiftUI

// MARK: - Layout Constants

enum LayoutConstants {
    enum Padding {
        static let extraSmall: CGFloat = 2
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
        static let huge: CGFloat = 40
    }
    
    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 16
    }
    
    enum FontSize {
        static let caption: CGFloat = 10
        static let small: CGFloat = 12
        static let body: CGFloat = 14
        static let large: CGFloat = 16
        static let title: CGFloat = 17
        static let bigTitle: CGFloat = 18
        
        // Font size range for content
        static let contentMinSize: CGFloat = 12
        static let contentMaxSize: CGFloat = 24
        static let contentDefaultSize: CGFloat = large
    }
    
    enum Animation {
        static let quick: Double = 0.2
        static let standard: Double = 0.3
        static let slow: Double = 0.5
    }
    
    enum Spacing {
        static let none: CGFloat = 0
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 16
    }
    
    enum Size {
        static let iconSmall: CGFloat = 24
        static let tearZoneHeight: CGFloat = 40
        static let maxContentWidth: CGFloat = 600
        static let tagSuggestionBarHeight: CGFloat = 50
        static let tagRowHeight: CGFloat = 32
        static let dictationButton: CGFloat = 52
    }
}

// MARK: - Gesture Constants

enum GestureConstants {
    // Require near-full progress to archive; prevents accidental saves on partial drags
    static let tearThreshold: CGFloat = 0.95
    static let minimumDragDistance: CGFloat = 10
    static let hapticInterval: CGFloat = 0.04
    static let tearProgressMultiplier: CGFloat = 200
}

// MARK: - Cache Constants

enum CacheConstants {
    static let tagCacheLimit: Int = 1000
    static let tagCacheSizeLimit: Int = 10 * 1024 * 1024 // 10MB
    static let tagUpdateDelay: TimeInterval = 0.3
}

// MARK: - Validation Constants

enum ValidationConstants {
    static let maxNoteContentLength: Int = 1_000_000 // 1MB of text
    static let maxNoteTitleLength: Int = 500
    static let maxTagLength: Int = 50
    static let maxTagsPerNote: Int = 50
}
