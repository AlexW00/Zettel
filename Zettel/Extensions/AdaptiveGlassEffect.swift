import SwiftUI

/// Extension providing a reusable glass tint color that adapts to color scheme and custom background state.
extension View {
    /// Returns the appropriate glass tint color based on color scheme and whether a custom background is active.
    /// In dark mode without a custom background, uses dark gray for better contrast.
    /// In dark mode with a custom background, uses black.
    /// In light mode, uses white.
    @ViewBuilder
    func adaptiveGlassEffect<S: Shape>(
        in shape: S,
        colorScheme: ColorScheme,
        hasCustomBackground: Bool
    ) -> some View {
        let tintColor: Color = {
            if colorScheme == .dark {
                if hasCustomBackground {
                    return .black.opacity(ThemeConstants.Opacity.glassTintOpacity)
                } else {
                    return Color(white: 0.15).opacity(ThemeConstants.Opacity.glassTintOpacity)
                }
            } else {
                return .white.opacity(ThemeConstants.Opacity.glassTintOpacity)
            }
        }()
        
        self.glassEffect(
            .clear.interactive().tint(tintColor),
            in: shape
        )
    }
}
