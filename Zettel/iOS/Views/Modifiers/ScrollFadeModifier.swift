import SwiftUI

struct ScrollFadeModifier: ViewModifier {
    let color: Color
    let width: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                LinearGradient(colors: [color, color.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: width)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                LinearGradient(colors: [color.opacity(0), color], startPoint: .leading, endPoint: .trailing)
                    .frame(width: width)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func horizontalScrollFades(color: Color, width: CGFloat = 24) -> some View {
        modifier(ScrollFadeModifier(color: color, width: width))
    }
}
