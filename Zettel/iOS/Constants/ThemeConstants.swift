//
//  ThemeConstants.swift
//  Zettel
//
//  Created by GitHub Copilot on 08.07.25.
//
//  Theme constants for consistent styling across the application.
//

import Foundation

/// Theme constants for consistent styling throughout the application
enum ThemeConstants {
    /// Opacity values for consistent transparency effects
    enum Opacity {
        /// Light opacity for subtle backgrounds (0.1)
        static let light: Double = 0.1
        
        /// Medium opacity for moderate emphasis (0.3)
        static let medium: Double = 0.3
        
        /// Heavy opacity for strong emphasis (0.5)
        static let heavy: Double = 0.5
        
        /// Very heavy opacity for maximum emphasis (0.75)
        static let veryHeavy: Double = 0.75
    }
    
    /// Shadow values for consistent depth effects
    enum Shadow {
        /// Small shadow for subtle depth (3)
        static let small: CGFloat = 3
        
        /// Medium shadow for moderate depth (4)
        static let medium: CGFloat = 4
    }
}
