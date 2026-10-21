import AppKit
import SwoopCore

/// Runs actions on windows: works out the target frame, remembers history for Undo,
/// animates, and handles the special cases (fullscreen, screens, stash...).
final class WindowEngine {
    static let shared = WindowEngine()

    private var history = FrameHistory()
    var cycles = CycleTracker()
    let animator = FrameAnimator()
    private(set) lazy var stash = StashManager(engine: self)

    private var settings: SwoopSettings { SettingsStore.shared.settings }

    private init() {}

    func isExcluded(_ window: AXWindow) -> Bool {
        guard let id = window.app?.bundleIdentifier else { return false }
        return settings.excludedBundleIDs.contains(id)
    }

    // MARK: - Planning (also used for the live preview)

    /// Where `ref` would put the window, or nil when there's nothing to show (minimize, hide...).
    func targetFrame(for ref: ActionRef, window: AXWindow) -> CGRect? {
        guard let current = window.frame, let located = Screens.locate(current) else { return nil }
        let index = located.index
        let screens = located.screens
        let screen = screens[index]
        let geometry = settings.geometry

        switch ref {
        case .custom(let id):
            guard let layout = settings.customLayouts.first(where: { $0.id == id }) else { return nil }
            return geometry.frame(forUnit: layout.unitRect, visible: screen.visible)

        case .builtin(let action):
            if let frame = geometry.frame(for: action, window: current, visible: screen.visible) {
                return frame
            }
            switch action {
            case .fullscreen:
                return screen.frame
            case .undo:
                return history.peekUndo(windowID: window.id)
            case .initialFrame:
                return history.initialFrame(windowID: window.id)
            case .stashLeft, .stashRight:
                let side: StashSide = action == .stashLeft ? .left : .right
                guard StashGeometry.edgeIsFree(side, screen: screen.frame, otherScreens: screens.map(\.frame)) else { return nil }
                return StashGeometry.hiddenFrame(window: current, screen: screen.frame, side: side,
                                                 peek: CGFloat(settings.stashPeek))
            case .unstash:
                return stash.originalFrame(for: window)
            default:
                guard let target = action.screenTarget,
                      let next = ScreenPicker.pick(target, current: index, screens: screens.map(\.frame)) else { return nil }
                return geometry.transfer(current, from: screen.visible, to: screens[next].visible)
            }
        }
    }

    // MARK: - Doing

    /// Runs an action on `window` (or the frontmost window). `completion` gets the frame the window
    /// actually ended up with, which apps with minimum sizes can make differ from the target.
    func perform(_ ref: ActionRef, on given: AXWindow? = nil, completion: ((AXWindow, CGRect?) -> Void)? = nil) {
        // After the free trial, actions need a license.
        guard LicenseManager.shared.allowAction() else { return }
        guard let window = given ?? AXWindow.frontmost() else {
            NSSound.beep()
            return
        }
        guard !isExcluded(window) else { return }

        switch ref.builtin {
        case .minimize?:
            window.minimize()
            return
        case .hide?:
            window.app?.hide()
            return
        case .fullscreen?:
            window.setFullscreen(!window.isFullscreen)
            return
        case .stashLeft?:
            stash.stash(window, side: .left)
            return
        case .stashRight?:
            stash.stash(window, side: .right)
            return
        case .unstash?:
            stash.unstash(window)
            return
        case .undo?:
            guard let previous = history.popUndo(windowID: window.id) else {
                NSSound.beep()
                return
            }
            stash.forget(window)
            move(window, to: previous) { completion?(window, $0) }
            return
        default:
            break
        }

        // Native fullscreen windows can't be moved; leave fullscreen first, then try again.
        if window.isFullscreen {
            window.setFullscreen(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.perform(ref, on: window, completion: completion)
            }
            return
        }

        guard let current = window.frame, let target = targetFrame(for: ref, window: window) else {
            NSSound.beep()
            return
        }

        stash.forget(window)
        recordHistory(window, frame: current)
        let changesScreen = ref.builtin?.screenTarget != nil
        move(window, to: target) { [weak self] final in
            if changesScreen, self?.settings.moveCursorWithWindow == true {
                CGWarpMouseCursorPosition((final ?? target).center)
                CGAssociateMouseAndMouseCursorPosition(1)
            }
            completion?(window, final)
        }
    }

    func recordHistory(_ window: AXWindow, frame: CGRect) {
        history.record(windowID: window.id, frame: frame)
    }

    /// Animated (or instant, per settings) move. Reports the real final frame.
    func move(_ window: AXWindow, to target: CGRect, completion: ((CGRect?) -> Void)? = nil) {
        let duration = settings.animateWindows ? settings.animationDuration : 0
        animator.animate(window, to: target, duration: duration) {
            completion?(window.frame)
        }
    }
}
