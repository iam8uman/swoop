import Foundation

/// Something Swoop can be told to do from outside: a `swoop://` URL, a shell script or Shortcuts.
public enum SwoopCommand: Equatable, Sendable {
    case action(ActionRef)
    /// Run whatever the radial menu has for this direction (its first action).
    case direction(RadialDirection)
    case list
    case openSettings
}

/// Parses `swoop://` URLs.
///
///     swoop://action/maximize          swoop://action/right-two-thirds
///     swoop://direction/top-left       swoop://screen/next
///     swoop://stash/left               swoop://unstash
///     swoop://custom/My%20Layout       swoop://undo
///     swoop://list/all                 swoop://settings
///
/// Names ignore case, spaces, dashes and underscores, so "Right Half", "right-half" and "rightHalf" all work.
public enum CommandParser {
    public static let scheme = "swoop"

    public static func normalize(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    public static func parse(_ url: URL, customLayouts: [CustomLayout] = []) -> SwoopCommand? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        var parts: [String] = []
        if let host = url.host, !host.isEmpty { parts.append(host) }
        parts += url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        parts = parts.map { $0.removingPercentEncoding ?? $0 }
        return parse(parts: parts, customLayouts: customLayouts)
    }

    public static func parse(parts: [String], customLayouts: [CustomLayout] = []) -> SwoopCommand? {
        guard let first = parts.first else { return nil }
        let verb = normalize(first)
        let argument = normalize(parts.dropFirst().joined(separator: " "))

        switch verb {
        case "action", "a", "do":
            return actionRef(named: argument, customLayouts: customLayouts).map { .action($0) }

        case "direction", "dir", "radial":
            return RadialDirection.allCases
                .first { normalize($0.rawValue) == argument || normalize($0.title) == argument }
                .map { .direction($0) }

        case "screen", "display":
            let map: [String: WindowAction] = [
                "next": .nextScreen, "previous": .previousScreen, "prev": .previousScreen,
                "left": .leftScreen, "right": .rightScreen,
                "top": .topScreen, "up": .topScreen, "bottom": .bottomScreen, "down": .bottomScreen,
            ]
            return map[argument].map { .action(.builtin($0)) }

        case "stash":
            switch argument {
            case "left": return .action(.builtin(.stashLeft))
            case "right": return .action(.builtin(.stashRight))
            default: return nil
            }

        case "unstash":
            return .action(.builtin(.unstash))

        case "undo":
            return .action(.builtin(.undo))

        case "custom", "layout":
            return customLayouts.first { normalize($0.name) == argument }.map { .action(.custom($0.id)) }

        case "list":
            return .list

        case "settings", "preferences", "prefs":
            return .openSettings

        default:
            // Shorthand: swoop://maximize
            return actionRef(named: verb, customLayouts: customLayouts).map { .action($0) }
        }
    }

    private static let aliases: [String: WindowAction] = [
        "max": .maximize,
        "centre": .center,
        "macoscentre": .macOSCenter,
        "full": .fullscreen,
        "fullscreen": .fullscreen,
        "lefthalf": .leftHalf,
        "righthalf": .rightHalf,
    ]

    public static func actionRef(named name: String, customLayouts: [CustomLayout] = []) -> ActionRef? {
        let n = normalize(name)
        guard !n.isEmpty else { return nil }
        if let a = WindowAction.allCases.first(where: { normalize($0.rawValue) == n || normalize($0.title) == n }) {
            return .builtin(a)
        }
        if let a = aliases[n] { return .builtin(a) }
        if let c = customLayouts.first(where: { normalize($0.name) == n }) { return .custom(c.id) }
        return nil
    }

    /// Every URL Swoop understands, for `swoop://list/all` and `Swoop --list`.
    public static func allCommands(customLayouts: [CustomLayout] = []) -> [String] {
        var out = WindowAction.allCases.map { "swoop://action/\(kebab($0.rawValue))" }
        out += RadialDirection.allCases.map { "swoop://direction/\(kebab($0.rawValue))" }
        out += ["next", "previous", "left", "right", "top", "bottom"].map { "swoop://screen/\($0)" }
        out += ["swoop://stash/left", "swoop://stash/right", "swoop://unstash", "swoop://undo"]
        out += customLayouts.map { "swoop://custom/\($0.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0.name)" }
        out += ["swoop://settings", "swoop://list/all"]
        return out
    }

    /// "rightTwoThirds" → "right-two-thirds"
    public static func kebab(_ camel: String) -> String {
        var out = ""
        for ch in camel.replacingOccurrences(of: "macOS", with: "Macos") {
            if ch.isUppercase {
                if !out.isEmpty { out.append("-") }
                out.append(Character(ch.lowercased()))
            } else {
                out.append(ch)
            }
        }
        return out
    }
}
