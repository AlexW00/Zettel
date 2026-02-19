//
//  Constants.swift
//  ZettelKit
//
//  Shared constants for the Zettel application.
//

import Foundation

// MARK: - Cache Constants

public enum CacheConstants {
    public static let tagCacheLimit: Int = 1000
    public static let tagCacheSizeLimit: Int = 10 * 1024 * 1024 // 10MB
    public static let tagUpdateDelay: TimeInterval = 0.3
}

// MARK: - Validation Constants

public enum ValidationConstants {
    public static let maxNoteContentLength: Int = 1_000_000 // 1MB of text
    public static let maxNoteTitleLength: Int = 500
    public static let maxTagLength: Int = 50
    public static let maxTagsPerNote: Int = 50
}

// MARK: - Theme Constants

public enum ThemeConstants {
    public enum Opacity {
        public static let light: Double = 0.1
        public static let medium: Double = 0.3
        public static let heavy: Double = 0.5
        public static let veryHeavy: Double = 0.75
        public static let glassTintOpacity: Double = 0.65
        public static let textShadowDark: Double = 0.8
        public static let textShadowLight: Double = 0.5
    }
    
    public enum Shadow {
        public static let small: CGFloat = 3
        public static let medium: CGFloat = 4
        public static let textRadius: CGFloat = 2.0
    }
}
