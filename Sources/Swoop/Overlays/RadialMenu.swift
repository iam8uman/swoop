import AppKit
import SwiftUI
import SwoopCore

/// What the radial menu is showing right now.
final class RadialModel: ObservableObject {
    @Published var theme = RadialTheme()
    @Published var highlighted: RadialDirection?
    /// Continuous angle (degrees) so the highlight always turns the short way round.
    @Published var angle: Double = 0
    @Published var centerActive = false
    @Published var title = ""
    @Published var subtitle: String?
    @Published var symbol: String?

    func set(direction: RadialDirection?, centerActive: Bool, title: String, subtitle: String?, symbol: String?) {
        if let a = direction?.angle {
            var target = a
            while target - angle > 180 { target -= 360 }
            while angle - target > 180 { target += 360 }
            angle = target
        }
        highlighted = direction
        self.centerActive = centerActive
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
    }
}

/// The ring itself. Also used live in Settings.
struct RadialMenuView: View {
    @ObservedObject var model: RadialModel
    var showsLabel = true

    var body: some View {
        let t = model.theme
        let d = CGFloat(t.diameter)
        let th = min(CGFloat(t.thickness), d / 2 - 4)
        let color = Color.swoopTheme(useAccent: t.useAccentColor, hex: t.colorHex)
        let shape = ringShape(t, inset: th / 2)

        VStack(spacing: 12) {
            ZStack {
                // Frosted ring.
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(shape.stroke(lineWidth: th))
                shape.stroke(Color.primary.opacity(0.10), lineWidth: th)
                outline(t, th: th)

                // Highlighted slice.
                if let dir = model.highlighted, dir != .center {
                    shape.stroke(color, lineWidth: th)
                        .mask(Wedge(angle: model.angle))
                        .shadow(color: color.opacity(0.6), radius: 8)
                }

                // Centre: shows the chosen action's icon.
                Circle()
                    .fill(model.centerActive ? AnyShapeStyle(color) : AnyShapeStyle(.thinMaterial))
                    .frame(width: max(d - th * 2 - 14, 12), height: max(d - th * 2 - 14, 12))
                    .overlay(
                        Image(systemName: model.symbol ?? "macwindow")
                            .font(.system(size: max(10, (d - th * 2) * 0.28), weight: .semibold))
                            .foregroundStyle(model.centerActive ? Color.white : Color.primary.opacity(0.75))
                            .opacity(model.symbol == nil ? 0.35 : 1)
                    )
            }
            .frame(width: d, height: d)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: model.angle)
            .animation(.easeOut(duration: 0.12), value: model.highlighted)

            if showsLabel && t.showLabel && !model.title.isEmpty {
                VStack(spacing: 2) {
                    Text(model.title)
                        .font(.system(size: 13, weight: .semibold))
                    if let sub = model.subtitle {
                        Text(sub)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
                .transition(.opacity)
            }
        }
    }

    private func ringShape(_ t: RadialTheme, inset: CGFloat) -> AnyShape {
        switch t.shape {
        case .circle:
            return AnyShape(Circle().inset(by: inset))
        case .roundedSquare:
            return AnyShape(RoundedRectangle(cornerRadius: CGFloat(t.cornerRadius), style: .continuous).inset(by: inset))
        }
    }

    @ViewBuilder
    private func outline(_ t: RadialTheme, th: CGFloat) -> some View {
        switch t.shape {
        case .circle:
            Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            Circle().inset(by: th).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        case .roundedSquare:
            RoundedRectangle(cornerRadius: CGFloat(t.cornerRadius), style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            RoundedRectangle(cornerRadius: max(0, CGFloat(t.cornerRadius) - th), style: .continuous)
                .inset(by: th)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
    }
}

/// A 45° pie slice pointing at `angle` (degrees, counter-clockwise from the right).
struct Wedge: Shape {
    var angle: Double
    var spread: Double = 45

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = max(rect.width, rect.height)
        var p = Path()
        p.move(to: c)
        let steps = 16
        for i in 0...steps {
            let deg = angle - spread / 2 + spread * Double(i) / Double(steps)
            let rad = deg * .pi / 180
            p.addLine(to: CGPoint(x: c.x + r * CGFloat(cos(rad)), y: c.y - r * CGFloat(sin(rad))))
        }
        p.closeSubpath()
        return p
    }
}

/// Puts the ring on screen, centred on where the cursor was when the trigger went down.
final class RadialMenuController {
    let model = RadialModel()
    private lazy var panel = OverlayPanel(
        level: .statusBar,
        content: RadialMenuView(model: model)
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    )

    func show(at point: CGPoint, theme: RadialTheme) {
        model.theme = theme
        let d = CGFloat(theme.diameter)
        let width = max(d + 40, 280)
        let height = d + 90
        let topPadding: CGFloat = 20
        let center = Screens.toAppKit(point: point)
        let origin = NSPoint(x: center.x - width / 2, y: center.y + d / 2 + topPadding - height)
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            self.panel.animator().alphaValue = 1
        }
    }

    func hide() {
        panel.orderOut(nil)
    }
}
