import CoreGraphics
import Foundation

extension CGFloat {
    /// Returns a safe value, replacing NaN or infinite values with a fallback
    func safeCGFloat(fallback: CGFloat = 0) -> CGFloat {
        return self.isFinite ? self : fallback
    }
    
    /// Safe division that prevents NaN results
    func safeDivide(by divisor: CGFloat, fallback: CGFloat = 0) -> CGFloat {
        guard divisor != 0 && divisor.isFinite && self.isFinite else {
            return fallback
        }
        let result = self / divisor
        return result.isFinite ? result : fallback
    }
    
    /// Safe multiplication that prevents NaN results
    func safeMultiply(by multiplier: CGFloat, fallback: CGFloat = 0) -> CGFloat {
        guard multiplier.isFinite && self.isFinite else {
            return fallback
        }
        let result = self * multiplier
        return result.isFinite ? result : fallback
    }
    
    /// Ensures the value is within a valid range
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        let safeValue = self.safeCGFloat(fallback: range.lowerBound)
        return Swift.min(Swift.max(safeValue, range.lowerBound), range.upperBound)
    }
}
