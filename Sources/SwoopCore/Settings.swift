import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Trigger key

/// A modifier key that can be (part of) the trigger. Left and right keys are distinct.
public enum TriggerKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case function
    case leftControl, rightControl
    case leftOption, rightOption
    case leftCommand, rightCommand
    case leftShift, rightShift

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .function: return "Fn / Globe 🌐"
        case .leftControl: return "Left Control ⌃"
        case .rightControl: return "Right Control ⌃"
        case .leftOption: return "Left Option ⌥"
        case .rightOption: return "Right Option ⌥"
        case .leftCommand: return "Left Command ⌘"
        case .rightCommand: return "Right Command ⌘"
        case .leftShift: return "Left Shift ⇧"
        case .rightShift: return "Right Shift ⇧"
        }
    }

    public var symbol: String {
        switch self {
        case .function: return "fn"
        case .leftControl: return "L⌃"
        case .rightControl: return "R⌃"
        case .leftOption: return "L⌥"
        case .rightOption: return "R⌥"
        case .leftCommand: return "L⌘"
        case .rightCommand: return "R⌘"
        case .leftShift: return "L⇧"
        case .rightShift: return "R⇧"
        }
    }

    /// Device-dependent bit in CGEventFlags (NX_DEVICE*KEYMASK) that is set while this exact key is down.
    public var deviceMask: UInt64 {
        switch self {
        case .function: return 0x80_0000 // maskSecondaryFn (no left/right variant)
        case .leftControl: return 0x0000_0001
        case .rightControl: return 0x0000_2000
        case .leftShift: return 0x0000_0002
        case .rightShift: return 0x0000_0004
        case .leftCommand: return 0x0000_0008
        case .rightCommand: return 0x0000_0010
        case .leftOption: return 0x0000_0020
        case .rightOption: return 0x0000_0040
        }
    }

    /// The generic modifier this key produces (nil for Fn, which isn't a shortcut modifier).
    public var modifier: ModifierKeys? {
        switch self {
        case .function: return nil
        case .leftControl, .rightControl: return .control
        case .leftOption, .rightOption: return .option
        case .leftCommand, .rightCommand: return .command
        case .leftShift, .rightShift: return .shift
        }
    }

    /// True when every key in `keys` is held, according to the CGEventFlags raw value.
    public static func allDown(_ keys: Set<TriggerKey>, flags: UInt64) -> Bool {
        guard !keys.isEmpty else { return false }
        return keys.allSatisfy { flags & $0.deviceMask != 0 }
    }

    /// Modifiers held IN ADDITION to the trigger, e.g. trigger = Right Option and the user
    /// also holds Shift → [.shift]. Used to match keybinds like "trigger + ⇧ + →".
    public static func extraModifiers(flags: UInt64, trigger: Set<TriggerKey>) -> ModifierKeys {
        typealias Side = (generic: UInt64, left: TriggerKey, right: TriggerKey, modifier: ModifierKeys)
        let sides: [Side] = [
            (0x2_0000, .leftShift, .rightShift, .shift),
            (0x4_0000, .leftControl, .rightControl, .control),
            (0x8_0000, .leftOption, .rightOption, .option),
            (0x10_0000, .leftCommand, .rightCommand, .command),
        ]
        var extra: ModifierKeys = []
        for s in sides where flags & s.generic != 0 {
            let leftDown = flags & s.left.deviceMask != 0
            let rightDown = flags & s.right.deviceMask != 0
            if !leftDown && !rightDown {
                // No device bits (synthetic event): count it unless the trigger uses this modifier.
                if !trigger.contains(s.left) && !trigger.contains(s.right) { extra.insert(s.modifier) }
                continue
            }
            let extraLeft = leftDown && !trigger.contains(s.left)
            let extraRight = rightDown && !trigger.contains(s.right)
            if extraLeft || extraRight { extra.insert(s.modifier) }
        }
        return extra
    }
}

// MARK: - Modifiers

public struct ModifierKeys: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = ModifierKeys(rawValue: 1 << 0)
    public static let option = ModifierKeys(rawValue: 1 << 1)
    public static let shift = ModifierKeys(rawValue: 1 << 2)
    public static let command = ModifierKeys(rawValue: 1 << 3)

    /// In the standard macOS order: ⌃⌥⇧⌘
    public var symbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(UInt8.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

// MARK: - Keybinds

/// Trigger + key (+ optional extra modifiers) runs an action. Several actions make a cycle:
/// pressing the same combination again steps to the next one.
public struct Keybind: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var keyCode: UInt16
    public var modifiers: ModifierKeys
    public var actions: [ActionRef]

    public init(id: UUID = UUID(), keyCode: UInt16, modifiers: ModifierKeys = [], actions: [ActionRef]) {
        self.id = id
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.actions = actions
    }

    public init(_ keyCode: UInt16, _ modifiers: ModifierKeys = [], _ actions: [WindowAction]) {
        self.init(keyCode: keyCode, modifiers: modifiers, actions: actions.map { .builtin($0) })
    }

    public var isCycle: Bool { actions.count > 1 }

    public var shortcutLabel: String { modifiers.symbols + KeyNames.name(for: keyCode) }

    private enum CodingKeys: String, CodingKey { case id, keyCode, modifiers, actions }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        keyCode = try c.decode(UInt16.self, forKey: .keyCode)
        modifiers = (try? c.decode(ModifierKeys.self, forKey: .modifiers)) ?? []
        // Unknown actions (from a newer version) are skipped instead of breaking the whole keybind.
        let raw = (try? c.decode([String].self, forKey: .actions)) ?? []
        actions = raw.compactMap(ActionRef.init(string:))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(keyCode, forKey: .keyCode)
        try c.encode(modifiers, forKey: .modifiers)
        try c.encode(actions.map(\.stringValue), forKey: .actions)
    }
}

/// Display names for macOS virtual key codes (US layout; the app swaps in the real layout when it can).
public enum KeyNames {
    public static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        65: "Num .", 67: "Num *", 69: "Num +", 71: "Clear", 75: "Num /", 76: "⌤", 78: "Num -", 81: "Num =",
        82: "Num 0", 83: "Num 1", 84: "Num 2", 85: "Num 3", 86: "Num 4", 87: "Num 5",
        88: "Num 6", 89: "Num 7", 91: "Num 8", 92: "Num 9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13",
        107: "F14", 109: "F10", 111: "F12", 113: "F15", 115: "↖", 116: "⇞", 117: "⌦",
        118: "F4", 119: "↘", 120: "F2", 121: "⇟", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }

    public static let escape: UInt16 = 53
}

// MARK: - Appearance

public enum RadialShape: String, Codable, CaseIterable, Identifiable, Sendable {
    case circle, roundedSquare
    public var id: String { rawValue }
    public var title: String { self == .circle ? "Circle" : "Rounded Square" }
}

public struct RadialTheme: Codable, Equatable, Sendable {
    public var diameter: Double = 110
    public var thickness: Double = 24
    public var shape: RadialShape = .circle
    public var cornerRadius: Double = 30
    public var useAccentColor = true
    public var colorHex = "#0A84FF"
    public var showLabel = true

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case diameter, thickness, shape, cornerRadius, useAccentColor, colorHex, showLabel
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = RadialTheme()
        diameter = c.value(.diameter, d.diameter)
        thickness = c.value(.thickness, d.thickness)
        shape = c.value(.shape, d.shape)
        cornerRadius = c.value(.cornerRadius, d.cornerRadius)
        useAccentColor = c.value(.useAccentColor, d.useAccentColor)
        colorHex = c.value(.colorHex, d.colorHex)
        showLabel = c.value(.showLabel, d.showLabel)
    }
}

public struct PreviewTheme: Codable, Equatable, Sendable {
    public var padding: Double = 8
    public var cornerRadius: Double = 12
    public var borderWidth: Double = 3
    public var fillOpacity: Double = 0.18
    public var useAccentColor = true
    public var colorHex = "#0A84FF"

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case padding, cornerRadius, borderWidth, fillOpacity, useAccentColor, colorHex
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PreviewTheme()
        padding = c.value(.padding, d.padding)
        cornerRadius = c.value(.cornerRadius, d.cornerRadius)
        borderWidth = c.value(.borderWidth, d.borderWidth)
        fillOpacity = c.value(.fillOpacity, d.fillOpacity)
        useAccentColor = c.value(.useAccentColor, d.useAccentColor)
        colorHex = c.value(.colorHex, d.colorHex)
    }
}

// MARK: - All settings

public struct SwoopSettings: Codable, Equatable, Sendable {
    // Trigger
    public var triggerKeys: Set<TriggerKey> = [.leftOption]
    /// Seconds the trigger must be held before the radial menu appears (keybinds work instantly).
    public var triggerDelay: Double = 0.15
    public var cursorSelection = true
    /// How far the cursor must move before a direction is picked.
    public var deadZone: Double = 12

    // Radial menu & preview
    public var radialMenuEnabled = true
    public var previewEnabled = true
    public var radialTheme = RadialTheme()
    public var previewTheme = PreviewTheme()

    // Window behaviour
    public var padding: Double = 6
    public var sizeStep: Double = 40
    public var animateWindows = true
    public var animationDuration: Double = 0.18
    public var moveCursorWithWindow = true
    public var hapticFeedback = true
    public var excludedBundleIDs: [String] = []

    // Stash
    public var stashPeek: Double = 12
    public var stashRevealOnHover = true

    // Actions
    public var radialActions: [RadialDirection: [ActionRef]] = SwoopSettings.defaultRadialActions
    public var keybinds: [Keybind] = SwoopSettings.defaultKeybinds
    public var customLayouts: [CustomLayout] = []

    public init() {}

    public func actions(for direction: RadialDirection) -> [ActionRef] {
        radialActions[direction] ?? []
    }

    public var geometry: ActionGeometry {
        ActionGeometry(padding: CGFloat(padding), step: CGFloat(sizeStep))
    }

    public func keybind(keyCode: UInt16, modifiers: ModifierKeys) -> Keybind? {
        keybinds.first { $0.keyCode == keyCode && $0.modifiers == modifiers && !$0.actions.isEmpty }
    }

    public func title(for ref: ActionRef) -> String {
        ref.title(customLayouts: customLayouts)
    }

    public static let defaultRadialActions: [RadialDirection: [ActionRef]] = {
        func refs(_ a: [WindowAction]) -> [ActionRef] { a.map { .builtin($0) } }
        return [
            .center: [],
            .top: refs([.maximize, .almostMaximize, .topHalf]),
            .topRight: refs([.topRightQuarter]),
            .right: refs([.rightHalf, .rightThird, .rightTwoThirds]),
            .bottomRight: refs([.bottomRightQuarter]),
            .bottom: refs([.bottomHalf, .bottomThird, .bottomTwoThirds]),
            .bottomLeft: refs([.bottomLeftQuarter]),
            .left: refs([.leftHalf, .leftThird, .leftTwoThirds]),
            .topLeft: refs([.topLeftQuarter]),
        ]
    }()

    public static let defaultKeybinds: [Keybind] = [
        Keybind(123, [], [.leftHalf, .leftThird, .leftTwoThirds]),
        Keybind(124, [], [.rightHalf, .rightThird, .rightTwoThirds]),
        Keybind(126, [], [.topHalf, .topThird, .topTwoThirds]),
        Keybind(125, [], [.bottomHalf, .bottomThird, .bottomTwoThirds]),
        Keybind(36, [], [.maximize, .almostMaximize]),
        Keybind(8, [], [.center, .macOSCenter]),
        Keybind(3, [], [.fullscreen]),
        Keybind(17, [], [.horizontalCenterThird]),
        Keybind(18, [], [.topLeftQuarter]),
        Keybind(19, [], [.topRightQuarter]),
        Keybind(20, [], [.bottomLeftQuarter]),
        Keybind(21, [], [.bottomRightQuarter]),
        Keybind(30, [], [.nextScreen]),
        Keybind(33, [], [.previousScreen]),
        Keybind(24, [], [.larger]),
        Keybind(27, [], [.smaller]),
        Keybind(123, .shift, [.moveLeft]),
        Keybind(124, .shift, [.moveRight]),
        Keybind(126, .shift, [.moveUp]),
        Keybind(125, .shift, [.moveDown]),
        Keybind(6, [], [.undo]),
        Keybind(34, [], [.initialFrame]),
        Keybind(43, [], [.stashLeft]),
        Keybind(47, [], [.stashRight]),
        Keybind(44, [], [.unstash]),
        Keybind(46, [], [.minimize]),
        Keybind(4, [], [.hide]),
    ]

    // Forgiving decoding: a missing or broken field falls back to its default
    // instead of throwing away the user's whole configuration.
    private enum CodingKeys: String, CodingKey {
        case triggerKeys, triggerDelay, cursorSelection, deadZone
        case radialMenuEnabled, previewEnabled, radialTheme, previewTheme
        case padding, sizeStep, animateWindows, animationDuration, moveCursorWithWindow, hapticFeedback, excludedBundleIDs
        case stashPeek, stashRevealOnHover
        case radialActions, keybinds, customLayouts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SwoopSettings()
        triggerKeys = Set(((try? c.decode([String].self, forKey: .triggerKeys)) ?? []).compactMap(TriggerKey.init(rawValue:)))
        if triggerKeys.isEmpty { triggerKeys = d.triggerKeys }
        triggerDelay = c.value(.triggerDelay, d.triggerDelay)
        cursorSelection = c.value(.cursorSelection, d.cursorSelection)
        deadZone = c.value(.deadZone, d.deadZone)
        radialMenuEnabled = c.value(.radialMenuEnabled, d.radialMenuEnabled)
        previewEnabled = c.value(.previewEnabled, d.previewEnabled)
        radialTheme = c.value(.radialTheme, d.radialTheme)
        previewTheme = c.value(.previewTheme, d.previewTheme)
        padding = c.value(.padding, d.padding)
        sizeStep = c.value(.sizeStep, d.sizeStep)
        animateWindows = c.value(.animateWindows, d.animateWindows)
        animationDuration = c.value(.animationDuration, d.animationDuration)
        moveCursorWithWindow = c.value(.moveCursorWithWindow, d.moveCursorWithWindow)
        hapticFeedback = c.value(.hapticFeedback, d.hapticFeedback)
        excludedBundleIDs = c.value(.excludedBundleIDs, d.excludedBundleIDs)
        stashPeek = c.value(.stashPeek, d.stashPeek)
        stashRevealOnHover = c.value(.stashRevealOnHover, d.stashRevealOnHover)
        customLayouts = c.value(.customLayouts, d.customLayouts)

        if let raw = try? c.decode([String: [String]].self, forKey: .radialActions) {
            var map: [RadialDirection: [ActionRef]] = [:]
            for (key, list) in raw {
                guard let dir = RadialDirection(rawValue: key) else { continue }
                map[dir] = list.compactMap(ActionRef.init(string:))
            }
            radialActions = map
        } else {
            radialActions = d.radialActions
        }

        if let list = try? c.decode([Failable<Keybind>].self, forKey: .keybinds) {
            keybinds = list.compactMap(\.value)
        } else {
            keybinds = d.keybinds
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(triggerKeys.map(\.rawValue).sorted(), forKey: .triggerKeys)
        try c.encode(triggerDelay, forKey: .triggerDelay)
        try c.encode(cursorSelection, forKey: .cursorSelection)
        try c.encode(deadZone, forKey: .deadZone)
        try c.encode(radialMenuEnabled, forKey: .radialMenuEnabled)
        try c.encode(previewEnabled, forKey: .previewEnabled)
        try c.encode(radialTheme, forKey: .radialTheme)
        try c.encode(previewTheme, forKey: .previewTheme)
        try c.encode(padding, forKey: .padding)
        try c.encode(sizeStep, forKey: .sizeStep)
        try c.encode(animateWindows, forKey: .animateWindows)
        try c.encode(animationDuration, forKey: .animationDuration)
        try c.encode(moveCursorWithWindow, forKey: .moveCursorWithWindow)
        try c.encode(hapticFeedback, forKey: .hapticFeedback)
        try c.encode(excludedBundleIDs, forKey: .excludedBundleIDs)
        try c.encode(stashPeek, forKey: .stashPeek)
        try c.encode(stashRevealOnHover, forKey: .stashRevealOnHover)
        var radial: [String: [String]] = [:]
        for (dir, list) in radialActions { radial[dir.rawValue] = list.map(\.stringValue) }
        try c.encode(radial, forKey: .radialActions)
        try c.encode(keybinds, forKey: .keybinds)
        try c.encode(customLayouts, forKey: .customLayouts)
    }
}

/// Decodes to nil instead of throwing, so one bad array element doesn't sink the array.
struct Failable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

extension KeyedDecodingContainer {
    /// Decode a value, falling back to a default if it's missing or malformed.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}
