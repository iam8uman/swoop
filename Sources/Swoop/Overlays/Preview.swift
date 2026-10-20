import AppKit
import SwiftUI
import SwoopCore

final class PreviewModel: ObservableObject {
    @Published var theme = PreviewTheme()
}

/// The translucent outline showing where the window will land.
struct PreviewView: View {
    @ObservedObject var model: PreviewModel

    var body: some View {
        let t = model.theme
        let color = Color.swoopTheme(useAccent: t.useAccentColor, hex: t.colorHex)
        let shape = RoundedRectangle(cornerRadius: CGFloat(t.cornerRadius), style: .continuous)
        ZStack {
            shape.fill(.ultraThinMaterial).opacity(0.55)
            shape.fill(color.opacity(t.fillOpacity))
            shape.strokeBorder(color, lineWidth: CGFloat(t.borderWidth))
        }
        .padding(CGFloat(t.padding))
    }
}

final class PreviewController {
    let model = PreviewModel()
    private lazy var panel = OverlayPanel(level: .floating, content: PreviewView(model: model))

    /// Shows (or moves) the preview to `target`. The first time it grows out of the window's current frame.
    func show(target: CGRect, from origin: CGRect?, theme: PreviewTheme) {
        model.theme = theme
        let to = Screens.toAppKit(target)
        if !panel.isVisible {
            let start = origin.map { Screens.toAppKit($0) } ?? to
            panel.setFrame(start, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.panel.animator().setFrame(to, display: true)
            self.panel.animator().alphaValue = 1
        }
    }

    func hide() {
        panel.orderOut(nil)
    }
}
