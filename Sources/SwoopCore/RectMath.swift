import Foundation

// All SwoopCore geometry uses "screen space" with the origin at the top-left of the
// main display and y growing downward. That is the coordinate system of the macOS
// Accessibility API and CGEvent locations, so the app layer only converts once.

extension CGRect {
    public var center: CGPoint { CGPoint(x: midX, y: midY) }

    /// Rounds the edges (not the size) to whole points so neighbouring windows meet exactly.
    public var pixelAligned: CGRect {
        let x = minX.rounded()
        let y = minY.rounded()
        return CGRect(x: x, y: y, width: maxX.rounded() - x, height: maxY.rounded() - y)
    }

    public func approximatelyEquals(_ other: CGRect, tolerance: CGFloat = 4) -> Bool {
        abs(minX - other.minX) <= tolerance &&
            abs(minY - other.minY) <= tolerance &&
            abs(width - other.width) <= tolerance &&
            abs(height - other.height) <= tolerance
    }

    /// Shrinks the rect to fit `area` if needed, then shifts it inside without resizing further.
    public func fitted(in area: CGRect) -> CGRect {
        let w = min(width, area.width)
        let h = min(height, area.height)
        let x = min(max(minX, area.minX), area.maxX - w)
        let y = min(max(minY, area.minY), area.maxY - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Linear interpolation between two rects (t in 0...1).
    public func interpolated(to target: CGRect, progress t: CGFloat) -> CGRect {
        CGRect(x: minX + (target.minX - minX) * t,
               y: minY + (target.minY - minY) * t,
               width: width + (target.width - width) * t,
               height: height + (target.height - height) * t)
    }

    /// Area of the overlap with another rect (0 when they don't touch).
    public func overlapArea(with other: CGRect) -> CGFloat {
        let i = intersection(other)
        return i.isNull ? 0 : i.width * i.height
    }
}

/// Ease-out cubic: fast start, gentle landing.
public func easeOutCubic(_ t: Double) -> Double {
    let c = min(max(t, 0), 1)
    return 1 - pow(1 - c, 3)
}
