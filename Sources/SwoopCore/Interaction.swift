import Foundation

/// The nine zones of the radial menu.
public enum RadialDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case center, top, topRight, right, bottomRight, bottom, bottomLeft, left, topLeft

    public var id: String { rawValue }

    /// The eight directions around the ring, counter-clockwise from the right.
    public static let ring: [RadialDirection] = [.right, .topRight, .top, .topLeft, .left, .bottomLeft, .bottom, .bottomRight]

    /// Angle in degrees, counter-clockwise from "right" (math orientation). nil for the centre.
    public var angle: Double? {
        guard let i = RadialDirection.ring.firstIndex(of: self) else { return nil }
        return Double(i) * 45
    }

    public var title: String {
        switch self {
        case .center: return "Centre"
        case .top: return "Up"
        case .topRight: return "Up Right"
        case .right: return "Right"
        case .bottomRight: return "Down Right"
        case .bottom: return "Down"
        case .bottomLeft: return "Down Left"
        case .left: return "Left"
        case .topLeft: return "Up Left"
        }
    }

    public var arrow: String {
        switch self {
        case .center: return "●"
        case .top: return "↑"
        case .topRight: return "↗"
        case .right: return "→"
        case .bottomRight: return "↘"
        case .bottom: return "↓"
        case .bottomLeft: return "↙"
        case .left: return "←"
        case .topLeft: return "↖"
        }
    }

    /// Direction from cursor movement. `dx` grows right, `dy` grows UP (math orientation).
    /// Movement shorter than `deadZone` stays in the centre.
    public static func from(dx: Double, dy: Double, deadZone: Double) -> RadialDirection {
        guard hypot(dx, dy) >= max(deadZone, 0.0001) else { return .center }
        var degrees = atan2(dy, dx) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        let index = Int((degrees + 22.5) / 45) % 8
        return ring[index]
    }
}

/// Remembers the last cycle step so pressing the same key (or moving the same way) again
/// continues the cycle: Right Half → Right Third → Right Two Thirds → Right Half...
public struct CycleTracker: Sendable {
    private var lastKey: String?
    private var lastWindow: UInt32?
    private var lastIndex = 0
    private var lastFrame: CGRect?

    public init() {}

    /// Where to start a cycle. Continues only if it's the same key on the same window
    /// and the window is still where Swoop put it; otherwise starts from the first step.
    public func startIndex(key: String, windowID: UInt32, currentFrame: CGRect, count: Int) -> Int {
        guard count > 1,
              key == lastKey,
              windowID == lastWindow,
              let frame = lastFrame,
              frame.approximatelyEquals(currentFrame, tolerance: 6) else { return 0 }
        return (lastIndex + 1) % count
    }

    public mutating func record(key: String, windowID: UInt32, index: Int, frame: CGRect) {
        lastKey = key
        lastWindow = windowID
        lastIndex = index
        lastFrame = frame
    }

    public mutating func reset() {
        lastKey = nil
        lastWindow = nil
        lastFrame = nil
        lastIndex = 0
    }
}

/// Per-window undo stack plus each window's frame from before Swoop first touched it.
public struct FrameHistory: Sendable {
    private var stacks: [UInt32: [CGRect]] = [:]
    private var initial: [UInt32: CGRect] = [:]
    public var limit: Int

    public init(limit: Int = 30) {
        self.limit = limit
    }

    /// Call before changing a window's frame.
    public mutating func record(windowID: UInt32, frame: CGRect) {
        if initial[windowID] == nil { initial[windowID] = frame }
        var stack = stacks[windowID] ?? []
        if let last = stack.last, last.approximatelyEquals(frame, tolerance: 1) { return }
        stack.append(frame)
        if stack.count > limit { stack.removeFirst(stack.count - limit) }
        stacks[windowID] = stack
    }

    public func peekUndo(windowID: UInt32) -> CGRect? {
        stacks[windowID]?.last
    }

    public mutating func popUndo(windowID: UInt32) -> CGRect? {
        stacks[windowID]?.popLast()
    }

    public func initialFrame(windowID: UInt32) -> CGRect? {
        initial[windowID]
    }

    public mutating func forget(windowID: UInt32) {
        stacks[windowID] = nil
        initial[windowID] = nil
    }
}
