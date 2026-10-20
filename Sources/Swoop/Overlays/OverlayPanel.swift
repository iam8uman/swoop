import AppKit
import SwiftUI

/// A transparent, click-through window that floats above everything on every Space,
/// without ever taking focus away from the window being moved.
final class OverlayPanel: NSPanel {
    init<Content: View>(level: NSWindow.Level, content: Content) {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        self.level = level
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let host = NSHostingView(rootView: content)
        host.wantsLayer = true
        host.layer?.backgroundColor = .clear
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
