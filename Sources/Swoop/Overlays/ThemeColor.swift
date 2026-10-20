import AppKit
import SwiftUI

extension Color {
    /// "#RRGGBB" or "RRGGBB".
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255,
                  opacity: 1)
    }

    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#0A84FF" }
        return String(format: "#%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }

    /// The user's macOS accent colour, or their custom brand colour.
    static func swoopTheme(useAccent: Bool, hex: String) -> Color {
        useAccent ? Color(nsColor: .controlAccentColor) : (Color(hex: hex) ?? Color(nsColor: .controlAccentColor))
    }
}

/// Lets a ColorPicker edit a hex string setting.
func hexColorBinding(_ hex: Binding<String>) -> Binding<Color> {
    Binding(
        get: { Color(hex: hex.wrappedValue) ?? .accentColor },
        set: { hex.wrappedValue = $0.hexString }
    )
}
