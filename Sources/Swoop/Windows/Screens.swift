import AppKit
import SwoopCore

/// One display, in screen space (top-left origin, y down) like the Accessibility API.
struct ScreenInfo {
    let screen: NSScreen
    /// Whole display.
    let frame: CGRect
    /// Minus menu bar and Dock.
    let visible: CGRect
}

enum Screens {
    /// AppKit's origin is the bottom-left of the main display; Accessibility's is its top-left.
    static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    static func toScreenSpace(_ r: NSRect) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    static func toAppKit(_ r: CGRect) -> NSRect {
        NSRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    static func toAppKit(point p: CGPoint) -> NSPoint {
        NSPoint(x: p.x, y: primaryHeight - p.y)
    }

    static func toScreenSpace(point p: NSPoint) -> CGPoint {
        CGPoint(x: p.x, y: primaryHeight - p.y)
    }

    static func all() -> [ScreenInfo] {
        NSScreen.screens.map {
            ScreenInfo(screen: $0, frame: toScreenSpace($0.frame), visible: toScreenSpace($0.visibleFrame))
        }
    }

    /// The display a window is mostly on, plus all displays (handy for screen switching).
    static func locate(_ window: CGRect) -> (index: Int, screens: [ScreenInfo])? {
        let screens = all()
        guard let i = ScreenPicker.screenIndex(for: window, screens: screens.map(\.frame)) else { return nil }
        return (i, screens)
    }

    /// Current mouse position in screen space.
    static var mouseLocation: CGPoint {
        toScreenSpace(point: NSEvent.mouseLocation)
    }
}
