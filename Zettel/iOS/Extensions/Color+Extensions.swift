import SwiftUI

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.currentIndex = hex.startIndex
        
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255
        
        self.init(red: r, green: g, blue: b)
    }
    
    // MARK: - Accent and Selection Colors
    
    /// Accent color for selections and highlights - adapts to dark mode
    static var accentColor: Color {
        Color(UIColor.systemBlue)
    }
    
    /// Color for selected text - adapts to dark mode
    static var selectedTextColor: Color {
        Color(UIColor.label)
    }
    
    /// Color for inactive/unselected states
    static var inactiveColor: Color {
        Color(UIColor.systemGray)
    }
    
    /// Consistent icon tint color
    static var iconTint: Color {
        Color(UIColor.tintColor)
    }
    
    // MARK: - Opacity Constants
    
    /// Light opacity for subtle backgrounds
    static let lightOpacity = 0.1
    
    /// Medium opacity for moderate emphasis
    static let mediumOpacity = 0.3
    
    /// Heavy opacity for strong emphasis
    static let heavyOpacity = 0.5
}