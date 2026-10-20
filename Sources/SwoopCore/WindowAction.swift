import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public enum ActionCategory: String, CaseIterable, Sendable {
    case general = "General"
    case halves = "Halves"
    case quarters = "Quarters"
    case horizontalThirds = "Horizontal Thirds"
    case verticalThirds = "Vertical Thirds"
    case screens = "Screens"
    case sizeAndPosition = "Size & Position"
    case stash = "Stash"
    case more = "More"

    public var actions: [WindowAction] {
        WindowAction.allCases.filter { $0.category == self }
    }
}

/// Every built-in thing Swoop can do to a window.
public enum WindowAction: String, Codable, CaseIterable, Identifiable, Sendable {
    // General
    case maximize, almostMaximize, fullscreen, center, macOSCenter, minimize, hide
    // Halves
    case leftHalf, rightHalf, topHalf, bottomHalf
    // Quarters
    case topLeftQuarter, topRightQuarter, bottomLeftQuarter, bottomRightQuarter
    // Horizontal thirds (columns)
    case leftThird, leftTwoThirds, horizontalCenterThird, rightTwoThirds, rightThird
    // Vertical thirds (rows)
    case topThird, topTwoThirds, verticalCenterThird, bottomTwoThirds, bottomThird
    // Screens
    case nextScreen, previousScreen, leftScreen, rightScreen, topScreen, bottomScreen
    // Size & position
    case larger, smaller
    case growTop, growBottom, growLeft, growRight
    case shrinkTop, shrinkBottom, shrinkLeft, shrinkRight
    case moveUp, moveDown, moveLeft, moveRight
    // Stash
    case stashLeft, stashRight, unstash
    // More
    case undo, initialFrame

    public var id: String { rawValue }

    public var category: ActionCategory {
        switch self {
        case .maximize, .almostMaximize, .fullscreen, .center, .macOSCenter, .minimize, .hide:
            return .general
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf:
            return .halves
        case .topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter:
            return .quarters
        case .leftThird, .leftTwoThirds, .horizontalCenterThird, .rightTwoThirds, .rightThird:
            return .horizontalThirds
        case .topThird, .topTwoThirds, .verticalCenterThird, .bottomTwoThirds, .bottomThird:
            return .verticalThirds
        case .nextScreen, .previousScreen, .leftScreen, .rightScreen, .topScreen, .bottomScreen:
            return .screens
        case .larger, .smaller, .growTop, .growBottom, .growLeft, .growRight,
             .shrinkTop, .shrinkBottom, .shrinkLeft, .shrinkRight,
             .moveUp, .moveDown, .moveLeft, .moveRight:
            return .sizeAndPosition
        case .stashLeft, .stashRight, .unstash:
            return .stash
        case .undo, .initialFrame:
            return .more
        }
    }

    public var title: String {
        switch self {
        case .maximize: return "Maximize"
        case .almostMaximize: return "Almost Maximize"
        case .fullscreen: return "Fullscreen"
        case .center: return "Centre"
        case .macOSCenter: return "macOS Centre"
        case .minimize: return "Minimize"
        case .hide: return "Hide App"
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeftQuarter: return "Top Left Quarter"
        case .topRightQuarter: return "Top Right Quarter"
        case .bottomLeftQuarter: return "Bottom Left Quarter"
        case .bottomRightQuarter: return "Bottom Right Quarter"
        case .leftThird: return "Left Third"
        case .leftTwoThirds: return "Left Two Thirds"
        case .horizontalCenterThird: return "Centre Third"
        case .rightTwoThirds: return "Right Two Thirds"
        case .rightThird: return "Right Third"
        case .topThird: return "Top Third"
        case .topTwoThirds: return "Top Two Thirds"
        case .verticalCenterThird: return "Middle Third"
        case .bottomTwoThirds: return "Bottom Two Thirds"
        case .bottomThird: return "Bottom Third"
        case .nextScreen: return "Next Screen"
        case .previousScreen: return "Previous Screen"
        case .leftScreen: return "Left Screen"
        case .rightScreen: return "Right Screen"
        case .topScreen: return "Top Screen"
        case .bottomScreen: return "Bottom Screen"
        case .larger: return "Larger"
        case .smaller: return "Smaller"
        case .growTop: return "Grow Top"
        case .growBottom: return "Grow Bottom"
        case .growLeft: return "Grow Left"
        case .growRight: return "Grow Right"
        case .shrinkTop: return "Shrink Top"
        case .shrinkBottom: return "Shrink Bottom"
        case .shrinkLeft: return "Shrink Left"
        case .shrinkRight: return "Shrink Right"
        case .moveUp: return "Move Up"
        case .moveDown: return "Move Down"
        case .moveLeft: return "Move Left"
        case .moveRight: return "Move Right"
        case .stashLeft: return "Stash Left"
        case .stashRight: return "Stash Right"
        case .unstash: return "Unstash"
        case .undo: return "Undo"
        case .initialFrame: return "Initial Frame"
        }
    }

    /// SF Symbol used in menus and settings. Unknown names simply show no icon.
    public var symbolName: String {
        switch self {
        case .maximize, .almostMaximize: return "macwindow"
        case .fullscreen: return "arrow.up.left.and.arrow.down.right"
        case .center, .macOSCenter: return "rectangle.center.inset.filled"
        case .minimize: return "minus.rectangle"
        case .hide: return "eye.slash"
        case .leftHalf, .leftThird, .leftTwoThirds: return "rectangle.lefthalf.filled"
        case .rightHalf, .rightThird, .rightTwoThirds: return "rectangle.righthalf.filled"
        case .topHalf, .topThird, .topTwoThirds: return "rectangle.tophalf.filled"
        case .bottomHalf, .bottomThird, .bottomTwoThirds: return "rectangle.bottomhalf.filled"
        case .horizontalCenterThird, .verticalCenterThird: return "rectangle.split.3x1"
        case .topLeftQuarter: return "rectangle.inset.topleft.filled"
        case .topRightQuarter: return "rectangle.inset.topright.filled"
        case .bottomLeftQuarter: return "rectangle.inset.bottomleft.filled"
        case .bottomRightQuarter: return "rectangle.inset.bottomright.filled"
        case .nextScreen, .rightScreen: return "arrow.right.to.line"
        case .previousScreen, .leftScreen: return "arrow.left.to.line"
        case .topScreen: return "arrow.up.to.line"
        case .bottomScreen: return "arrow.down.to.line"
        case .larger, .growTop, .growBottom, .growLeft, .growRight: return "arrow.up.left.and.arrow.down.right"
        case .smaller, .shrinkTop, .shrinkBottom, .shrinkLeft, .shrinkRight: return "arrow.down.right.and.arrow.up.left"
        case .moveUp: return "arrow.up"
        case .moveDown: return "arrow.down"
        case .moveLeft: return "arrow.left"
        case .moveRight: return "arrow.right"
        case .stashLeft: return "sidebar.left"
        case .stashRight: return "sidebar.right"
        case .unstash: return "rectangle.portrait.and.arrow.right"
        case .undo: return "arrow.uturn.backward"
        case .initialFrame: return "clock.arrow.circlepath"
        }
    }

    /// For layout actions: the target area as fractions of the usable screen
    /// (x, y from the top-left; width, height). nil for actions that aren't a fixed layout.
    public var unitRect: CGRect? {
        let third: CGFloat = 1.0 / 3.0
        switch self {
        case .maximize: return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .almostMaximize: return CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
        case .leftHalf: return CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf: return CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf: return CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .bottomHalf: return CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .topLeftQuarter: return CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRightQuarter: return CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeftQuarter: return CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRightQuarter: return CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .leftThird: return CGRect(x: 0, y: 0, width: third, height: 1)
        case .leftTwoThirds: return CGRect(x: 0, y: 0, width: 2 * third, height: 1)
        case .horizontalCenterThird: return CGRect(x: third, y: 0, width: third, height: 1)
        case .rightTwoThirds: return CGRect(x: third, y: 0, width: 2 * third, height: 1)
        case .rightThird: return CGRect(x: 2 * third, y: 0, width: third, height: 1)
        case .topThird: return CGRect(x: 0, y: 0, width: 1, height: third)
        case .topTwoThirds: return CGRect(x: 0, y: 0, width: 1, height: 2 * third)
        case .verticalCenterThird: return CGRect(x: 0, y: third, width: 1, height: third)
        case .bottomTwoThirds: return CGRect(x: 0, y: third, width: 1, height: 2 * third)
        case .bottomThird: return CGRect(x: 0, y: 2 * third, width: 1, height: third)
        default: return nil
        }
    }

    /// Which way a screen-switching action goes, if it is one.
    public var screenTarget: ScreenTarget? {
        switch self {
        case .nextScreen: return .next
        case .previousScreen: return .previous
        case .leftScreen: return .left
        case .rightScreen: return .right
        case .topScreen: return .up
        case .bottomScreen: return .down
        default: return nil
        }
    }
}

/// A reference to something Swoop can do: a built-in action or one of the user's custom layouts.
/// Stored as a plain string ("maximize", "custom:<uuid>") so settings stay readable and forward-compatible.
public enum ActionRef: Hashable, Codable, Sendable {
    case builtin(WindowAction)
    case custom(UUID)

    public init?(string: String) {
        if string.hasPrefix("custom:") {
            guard let id = UUID(uuidString: String(string.dropFirst("custom:".count))) else { return nil }
            self = .custom(id)
        } else if let action = WindowAction(rawValue: string) {
            self = .builtin(action)
        } else {
            return nil
        }
    }

    public var stringValue: String {
        switch self {
        case .builtin(let a): return a.rawValue
        case .custom(let id): return "custom:" + id.uuidString
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let ref = ActionRef(string: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Unknown action \(raw)"))
        }
        self = ref
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(stringValue)
    }

    public var builtin: WindowAction? {
        if case .builtin(let a) = self { return a }
        return nil
    }
}

/// A user-defined layout, as fractions (0...1) of the usable screen area.
public struct CustomLayout: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(id: UUID = UUID(), name: String, x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Clamped so the layout always stays on screen.
    public var unitRect: CGRect {
        let w = min(max(width, 0.05), 1)
        let h = min(max(height, 0.05), 1)
        let x = min(max(self.x, 0), 1 - w)
        let y = min(max(self.y, 0), 1 - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

extension ActionRef {
    /// Display name, looking custom layouts up by id.
    public func title(customLayouts: [CustomLayout]) -> String {
        switch self {
        case .builtin(let a): return a.title
        case .custom(let id): return customLayouts.first { $0.id == id }?.name ?? "Missing Layout"
        }
    }
}
