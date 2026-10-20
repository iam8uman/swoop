import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Works out where a window should go for an action. Pure math, screen space (top-left origin).
public struct ActionGeometry: Sendable {
    /// Gap between tiled windows and around the screen edge.
    public var padding: CGFloat
    /// How far Larger / Smaller / Grow / Shrink / Move go per press.
    public var step: CGFloat
    /// Smaller and Shrink never go below this.
    public var minimumSize: CGSize

    public init(padding: CGFloat = 0, step: CGFloat = 40, minimumSize: CGSize = CGSize(width: 240, height: 160)) {
        self.padding = max(0, padding)
        self.step = max(1, step)
        self.minimumSize = minimumSize
    }

    /// A layout given as fractions of the usable screen.
    /// Outer edges get the full padding and the gap between two tiled windows is also exactly `padding`.
    public func frame(forUnit unit: CGRect, visible: CGRect) -> CGRect {
        let half = padding / 2
        let area = visible.insetBy(dx: half, dy: half)
        let raw = CGRect(x: area.minX + area.width * unit.minX,
                         y: area.minY + area.height * unit.minY,
                         width: area.width * unit.width,
                         height: area.height * unit.height)
        return raw.insetBy(dx: half, dy: half).pixelAligned
    }

    /// Target frame for a built-in action, or nil if the action isn't a pure geometry change
    /// (fullscreen, minimize, hide, screens, stash, undo... are handled by the app layer).
    public func frame(for action: WindowAction, window: CGRect, visible: CGRect) -> CGRect? {
        if let unit = action.unitRect {
            return frame(forUnit: unit, visible: visible)
        }

        let area = visible.insetBy(dx: padding, dy: padding)
        let minW = min(minimumSize.width, area.width)
        let minH = min(minimumSize.height, area.height)
        var r = window

        switch action {
        case .center, .macOSCenter:
            let w = min(window.width, area.width)
            let h = min(window.height, area.height)
            let x = area.midX - w / 2
            // macOS Centre sits a little above the middle, like NSWindow.center().
            let y = action == .center ? area.midY - h / 2 : area.minY + (area.height - h) / 3
            return CGRect(x: x, y: y, width: w, height: h).pixelAligned

        case .larger:
            r = window.insetBy(dx: -step, dy: -step).intersection(area)
            if r.isNull { r = window }
            return r.fitted(in: area).pixelAligned

        case .smaller:
            let w = max(minW, window.width - 2 * step)
            let h = max(minH, window.height - 2 * step)
            r = CGRect(x: window.midX - w / 2, y: window.midY - h / 2, width: w, height: h)
            return r.fitted(in: area).pixelAligned

        case .growTop:
            let top = max(area.minY, window.minY - step)
            r = CGRect(x: window.minX, y: top, width: window.width, height: window.maxY - top)
        case .growBottom:
            let bottom = min(area.maxY, window.maxY + step)
            r = CGRect(x: window.minX, y: window.minY, width: window.width, height: bottom - window.minY)
        case .growLeft:
            let left = max(area.minX, window.minX - step)
            r = CGRect(x: left, y: window.minY, width: window.maxX - left, height: window.height)
        case .growRight:
            let right = min(area.maxX, window.maxX + step)
            r = CGRect(x: window.minX, y: window.minY, width: right - window.minX, height: window.height)

        case .shrinkTop:
            let top = min(window.minY + step, window.maxY - minH)
            r = CGRect(x: window.minX, y: top, width: window.width, height: window.maxY - top)
        case .shrinkBottom:
            let bottom = max(window.maxY - step, window.minY + minH)
            r = CGRect(x: window.minX, y: window.minY, width: window.width, height: bottom - window.minY)
        case .shrinkLeft:
            let left = min(window.minX + step, window.maxX - minW)
            r = CGRect(x: left, y: window.minY, width: window.maxX - left, height: window.height)
        case .shrinkRight:
            let right = max(window.maxX - step, window.minX + minW)
            r = CGRect(x: window.minX, y: window.minY, width: right - window.minX, height: window.height)

        case .moveUp:
            r = window.offsetBy(dx: 0, dy: -step)
            return r.fitted(in: area).pixelAligned
        case .moveDown:
            r = window.offsetBy(dx: 0, dy: step)
            return r.fitted(in: area).pixelAligned
        case .moveLeft:
            r = window.offsetBy(dx: -step, dy: 0)
            return r.fitted(in: area).pixelAligned
        case .moveRight:
            r = window.offsetBy(dx: step, dy: 0)
            return r.fitted(in: area).pixelAligned

        default:
            return nil
        }
        return r.pixelAligned
    }

    /// Moves a window to another screen, keeping its relative position and size.
    /// A window filling the left half of one screen fills the left half of the next.
    public func transfer(_ window: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return window.fitted(in: target) }
        let sx = target.width / source.width
        let sy = target.height / source.height
        let r = CGRect(x: target.minX + (window.minX - source.minX) * sx,
                       y: target.minY + (window.minY - source.minY) * sy,
                       width: window.width * sx,
                       height: window.height * sy)
        return r.fitted(in: target).pixelAligned
    }
}

// MARK: - Screens

public enum ScreenTarget: String, CaseIterable, Sendable {
    case next, previous, left, right, up, down
}

public enum ScreenPicker {
    /// Picks the index of the screen to move to. `screens` are full screen frames in screen space.
    public static func pick(_ target: ScreenTarget, current: Int, screens: [CGRect]) -> Int? {
        guard screens.count > 1, screens.indices.contains(current) else { return nil }

        switch target {
        case .next, .previous:
            // Reading order: left to right, then top to bottom.
            let order = screens.indices.sorted {
                let a = screens[$0], b = screens[$1]
                return a.minX != b.minX ? a.minX < b.minX : a.minY < b.minY
            }
            guard let pos = order.firstIndex(of: current) else { return nil }
            let step = target == .next ? 1 : -1
            return order[(pos + step + order.count) % order.count]

        case .left, .right, .up, .down:
            let here = screens[current].center
            var best: (index: Int, score: CGFloat)?
            for (i, s) in screens.enumerated() where i != current {
                let dx = s.center.x - here.x
                let dy = s.center.y - here.y // positive = below
                let primary: CGFloat
                let sideways: CGFloat
                switch target {
                case .left: primary = -dx; sideways = abs(dy)
                case .right: primary = dx; sideways = abs(dy)
                case .up: primary = -dy; sideways = abs(dx)
                default: primary = dy; sideways = abs(dx)
                }
                guard primary > 0 else { continue }
                // Prefer screens straight ahead over ones off to the side.
                let score = primary + sideways * 2
                if best == nil || score < best!.score { best = (i, score) }
            }
            return best?.index
        }
    }

    /// The screen a window is mostly on (largest overlap), or nil if it's on none of them.
    public static func screenIndex(for window: CGRect, screens: [CGRect]) -> Int? {
        var best: (Int, CGFloat)?
        for (i, s) in screens.enumerated() {
            let a = window.overlapArea(with: s)
            if a > 0, best == nil || a > best!.1 { best = (i, a) }
        }
        if let best { return best.0 }
        // Off every screen: pick the nearest by centre distance.
        let c = window.center
        return screens.indices.min {
            hypot(screens[$0].midX - c.x, screens[$0].midY - c.y) <
                hypot(screens[$1].midX - c.x, screens[$1].midY - c.y)
        }
    }
}

// MARK: - Stash

public enum StashSide: String, Codable, CaseIterable, Sendable {
    case left, right
}

public enum StashGeometry {
    /// Where a stashed window sits: almost entirely past the screen edge, with `peek` points showing.
    public static func hiddenFrame(window: CGRect, screen: CGRect, side: StashSide, peek: CGFloat) -> CGRect {
        let peek = max(1, peek)
        let x = side == .left ? screen.minX - window.width + peek : screen.maxX - peek
        let y = min(max(window.minY, screen.minY), screen.maxY - min(window.height, screen.height))
        return CGRect(x: x, y: y, width: window.width, height: window.height).pixelAligned
    }

    /// Where a stashed window slides to when revealed: flush against its edge.
    public static func revealedFrame(window: CGRect, screen: CGRect, side: StashSide) -> CGRect {
        let w = min(window.width, screen.width)
        let x = side == .left ? screen.minX : screen.maxX - w
        let y = min(max(window.minY, screen.minY), screen.maxY - min(window.height, screen.height))
        return CGRect(x: x, y: y, width: w, height: window.height).pixelAligned
    }

    /// False when another display touches that edge: a "hidden" window would just appear on it.
    public static func edgeIsFree(_ side: StashSide, screen: CGRect, otherScreens: [CGRect]) -> Bool {
        for o in otherScreens where o != screen {
            let verticalOverlap = min(o.maxY, screen.maxY) - max(o.minY, screen.minY) > 0
            guard verticalOverlap else { continue }
            if side == .left, abs(o.maxX - screen.minX) < 2 { return false }
            if side == .right, abs(o.minX - screen.maxX) < 2 { return false }
        }
        return true
    }

    /// The cursor is pushed against the edge, alongside the stashed window.
    public static func shouldReveal(cursor: CGPoint, hidden: CGRect, screen: CGRect, side: StashSide) -> Bool {
        let atEdge = side == .left ? cursor.x <= screen.minX + 2 : cursor.x >= screen.maxX - 3
        return atEdge && cursor.y >= hidden.minY && cursor.y <= hidden.maxY
    }
}
