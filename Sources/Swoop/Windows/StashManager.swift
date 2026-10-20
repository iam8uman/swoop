import AppKit
import SwoopCore

/// Stash: park a window just off the screen edge with a sliver showing. Push the cursor against
/// that edge and it slides back out; move away and it tucks itself in again.
final class StashManager {
    private struct Entry {
        let window: AXWindow
        let side: StashSide
        let screen: CGRect
        let hidden: CGRect
        let revealed: CGRect
        /// Where the window was before it was stashed (Unstash puts it back here).
        let original: CGRect
        var isRevealed = false
    }

    private unowned let engine: WindowEngine
    private var entries: [Entry] = []
    private var monitor: Any?
    private var settings: SwoopSettings { SettingsStore.shared.settings }

    init(engine: WindowEngine) {
        self.engine = engine
    }

    var stashedCount: Int { entries.count }

    func stash(_ window: AXWindow, side: StashSide) {
        guard let current = window.frame, let located = Screens.locate(current) else {
            NSSound.beep()
            return
        }
        let screens = located.screens
        let screen = screens[located.index].frame
        // If another display touches this edge, the "hidden" window would just show up there.
        guard StashGeometry.edgeIsFree(side, screen: screen, otherScreens: screens.map(\.frame)) else {
            NSSound.beep()
            return
        }

        // Re-stashing keeps the original pre-stash frame.
        let original = entries.first { $0.window.id == window.id }?.original ?? current
        let base = entries.first { $0.window.id == window.id }?.revealed ?? current
        entries.removeAll { $0.window.id == window.id }

        let hidden = StashGeometry.hiddenFrame(window: base, screen: screen, side: side, peek: CGFloat(settings.stashPeek))
        let revealed = StashGeometry.revealedFrame(window: base, screen: screen, side: side)
        entries.append(Entry(window: window, side: side, screen: screen, hidden: hidden, revealed: revealed, original: original))

        engine.recordHistory(window, frame: current)
        engine.move(window, to: hidden)
        startMonitoring()
    }

    func unstash(_ window: AXWindow) {
        guard let i = entries.firstIndex(where: { $0.window.id == window.id }) else {
            NSSound.beep()
            return
        }
        let entry = entries.remove(at: i)
        engine.move(window, to: entry.original)
        window.focus()
        stopMonitoringIfIdle()
    }

    func originalFrame(for window: AXWindow) -> CGRect? {
        entries.first { $0.window.id == window.id }?.original
    }

    /// The window was moved by another action, so it's no longer stashed.
    func forget(_ window: AXWindow) {
        entries.removeAll { $0.window.id == window.id }
        stopMonitoringIfIdle()
    }

    /// Put everything back (on quit), instantly.
    func unstashAll() {
        for e in entries where e.window.isAlive { e.window.setFrame(e.original) }
        entries.removeAll()
        stopMonitoringIfIdle()
    }

    // MARK: - Hover to reveal

    private func startMonitoring() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.mouseMoved(to: Screens.mouseLocation)
        }
    }

    private func stopMonitoringIfIdle() {
        guard entries.isEmpty, let m = monitor else { return }
        NSEvent.removeMonitor(m)
        monitor = nil
    }

    private func mouseMoved(to p: CGPoint) {
        guard settings.stashRevealOnHover else { return }
        for i in entries.indices.reversed() {
            let e = entries[i]
            if !e.isRevealed {
                guard StashGeometry.shouldReveal(cursor: p, hidden: e.hidden, screen: e.screen, side: e.side) else { continue }
                guard e.window.isAlive else {
                    entries.remove(at: i)
                    continue
                }
                entries[i].isRevealed = true
                engine.move(e.window, to: e.revealed)
                e.window.focus()
            } else if !e.revealed.insetBy(dx: -24, dy: -24).contains(p) {
                entries[i].isRevealed = false
                engine.move(e.window, to: e.hidden)
            }
        }
        stopMonitoringIfIdle()
    }
}
