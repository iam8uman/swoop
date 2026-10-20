import AppKit
import ApplicationServices

/// Another app's window, controlled through Accessibility.
final class AXWindow {
    let element: AXUIElement
    let pid: pid_t
    let id: CGWindowID

    init?(element: AXUIElement) {
        guard let id = AX.windowID(element) else { return nil }
        self.element = element
        self.pid = AX.pid(element)
        self.id = id
        AXUIElementSetMessagingTimeout(element, 0.3)
    }

    /// The window that has keyboard focus in the frontmost app (never Swoop's own windows).
    static func frontmost() -> AXWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid() else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.3)
        if let el = AX.element(appElement, kAXFocusedWindowAttribute), let w = AXWindow(element: el), w.isMovable {
            return w
        }
        if let el = AX.element(appElement, kAXMainWindowAttribute), let w = AXWindow(element: el), w.isMovable {
            return w
        }
        return AX.elements(appElement, kAXWindowsAttribute).lazy.compactMap(AXWindow.init(element:)).first { $0.isMovable }
    }

    /// Frame in screen space (top-left origin of the main display).
    var frame: CGRect? {
        guard let p = AX.position(element), let s = AX.size(element) else { return nil }
        return CGRect(origin: p, size: s)
    }

    /// Size, position, size: the second size call fixes apps that clamp a window
    /// while it is still partly on the previous screen.
    func setFrame(_ r: CGRect) {
        AX.setSize(element, r.size)
        AX.setPosition(element, r.origin)
        AX.setSize(element, r.size)
    }

    /// Cheaper per-frame update used during animation.
    func setFrameStep(_ r: CGRect, sizeChanged: Bool) {
        AX.setPosition(element, r.origin)
        if sizeChanged { AX.setSize(element, r.size) }
    }

    var isMovable: Bool { AX.isSettable(element, kAXPositionAttribute) }
    var isResizable: Bool { AX.isSettable(element, kAXSizeAttribute) }
    var isAlive: Bool { AX.string(element, kAXRoleAttribute) != nil }

    var isFullscreen: Bool { AX.bool(element, "AXFullScreen") == true }
    func setFullscreen(_ on: Bool) { AX.setBool(element, "AXFullScreen", on) }

    func minimize() { AX.setBool(element, kAXMinimizedAttribute, true) }

    var app: NSRunningApplication? { NSRunningApplication(processIdentifier: pid) }

    /// Bring to front with keyboard focus.
    func focus() {
        let appElement = AXUIElementCreateApplication(pid)
        AX.setBool(appElement, kAXFrontmostAttribute, true)
        AX.setBool(element, kAXMainAttribute, true)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }
}
