import AppKit
import SwoopCore

private func triggerTapCallback(proxy: CGEventTapProxy,
                                type: CGEventType,
                                event: CGEvent,
                                refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<TriggerController>.fromOpaque(refcon).takeUnretainedValue()
    return controller.handle(type: type, event: event)
}

/// The heart of Swoop. Watches the trigger key, then:
///   • cursor movement picks a direction on the radial menu,
///   • left-click cycles through that direction's actions,
///   • trigger + key runs a keybind (pressing it again cycles),
///   • releasing the trigger applies the choice; Esc or right-click cancels.
/// Keys that aren't keybinds pass straight through and cancel, so typing with
/// the trigger modifier (e.g. ⌥ for special characters) never gets in the way.
final class TriggerController {
    enum Source: Equatable {
        case direction(RadialDirection)
        case keybind(UUID)

        var cycleKey: String {
            switch self {
            case .direction(let d): return "direction:" + d.rawValue
            case .keybind(let id): return "keybind:" + id.uuidString
            }
        }

        var isKeybind: Bool {
            if case .keybind = self { return true }
            return false
        }
    }

    private struct Session {
        let window: AXWindow
        let start: CGPoint
        var source: Source?
        var index = 0
        var direction: RadialDirection = .center
        var visible = false
        var timer: Timer?
    }

    var isPaused = false
    private(set) var isRunning = false

    private var tap: CFMachPort?
    private var session: Session?
    private var triggerDown = false
    private var swallowedKeyUps = Set<Int64>()
    private var swallowMouseUp = false
    private var swallowRightMouseUp = false

    private let radial = RadialMenuController()
    private let preview = PreviewController()
    private let engine = WindowEngine.shared
    private var settings: SwoopSettings { SettingsStore.shared.settings }

    // MARK: - Event tap

    /// Needs Accessibility permission. Returns false if macOS refused the tap.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.flagsChanged, .keyDown, .keyUp, .mouseMoved,
                                    .leftMouseDown, .leftMouseUp, .leftMouseDragged,
                                    .rightMouseDown, .rightMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: mask,
                                          callback: triggerTapCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        isRunning = true
        return true
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass

        case .flagsChanged:
            let down = !isPaused && TriggerKey.allDown(settings.triggerKeys, flags: event.flags.rawValue)
            if down && !triggerDown {
                triggerDown = true
                begin(at: event.location)
            } else if !down && triggerDown {
                triggerDown = false
                end(commit: true)
            }
            return pass

        case .keyDown:
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            guard session != nil else { return pass }
            if code == Int64(KeyNames.escape) {
                end(commit: false)
                swallowedKeyUps.insert(code)
                return nil
            }
            let extra = TriggerKey.extraModifiers(flags: event.flags.rawValue, trigger: settings.triggerKeys)
            if let bind = settings.keybind(keyCode: UInt16(code), modifiers: extra) {
                swallowedKeyUps.insert(code)
                // Holding a key down shouldn't spin through the cycle.
                if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                    select(.keybind(bind.id), advanceIfSame: true)
                }
                return nil
            }
            // Not ours: the user is typing with the modifier held. Get out of the way.
            end(commit: false)
            return pass

        case .keyUp:
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            return swallowedKeyUps.remove(code) != nil ? nil : pass

        case .mouseMoved, .leftMouseDragged:
            guard var s = session, settings.cursorSelection else { return pass }
            let p = event.location
            let dir = RadialDirection.from(dx: Double(p.x - s.start.x),
                                           dy: Double(s.start.y - p.y), // flip: screen space y grows down
                                           deadZone: settings.deadZone)
            guard dir != s.direction else { return pass }
            s.direction = dir
            session = s
            // A keybind choice sticks until the cursor clearly leaves the centre.
            if dir == .center, s.source?.isKeybind == true { return pass }
            select(.direction(dir), advanceIfSame: false)
            return pass

        case .leftMouseDown:
            guard let s = session, s.visible else { return pass }
            if let src = s.source { select(src, advanceIfSame: true) }
            swallowMouseUp = true
            return nil

        case .leftMouseUp:
            if swallowMouseUp {
                swallowMouseUp = false
                return nil
            }
            return pass

        case .rightMouseDown:
            guard let s = session, s.visible else { return pass }
            end(commit: false)
            swallowRightMouseUp = true
            return nil

        case .rightMouseUp:
            if swallowRightMouseUp {
                swallowRightMouseUp = false
                return nil
            }
            return pass

        default:
            return pass
        }
    }

    // MARK: - Session

    private func begin(at point: CGPoint) {
        guard session == nil, let window = AXWindow.frontmost(), !engine.isExcluded(window) else { return }
        var s = Session(window: window, start: point)
        let timer = Timer(timeInterval: max(0, settings.triggerDelay), repeats: false) { [weak self] _ in
            self?.reveal()
        }
        RunLoop.main.add(timer, forMode: .common)
        s.timer = timer
        session = s
    }

    /// The trigger has been held long enough: show the menu.
    private func reveal() {
        guard var s = session, !s.visible else { return }
        s.visible = true
        session = s
        if settings.radialMenuEnabled { radial.show(at: s.start, theme: settings.radialTheme) }
        refresh()
    }

    private func actions(for source: Source) -> [ActionRef] {
        switch source {
        case .direction(let d): return settings.actions(for: d)
        case .keybind(let id): return settings.keybinds.first { $0.id == id }?.actions ?? []
        }
    }

    private func select(_ source: Source, advanceIfSame: Bool) {
        guard var s = session else { return }
        let list = actions(for: source)
        if s.source == source {
            if advanceIfSame, list.count > 1 { s.index = (s.index + 1) % list.count }
        } else {
            s.source = source
            s.index = engine.cycles.startIndex(key: source.cycleKey, windowID: s.window.id,
                                               currentFrame: s.window.frame ?? .zero, count: list.count)
        }
        session = s

        if source.isKeybind && !s.visible {
            // Keybinds act immediately; no need to wait for the hold delay.
            reveal()
        } else if s.visible {
            refresh()
        }
        if s.visible || source.isKeybind, settings.hapticFeedback, !list.isEmpty {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func currentAction(_ s: Session) -> ActionRef? {
        guard let src = s.source else { return nil }
        let list = actions(for: src)
        return list.isEmpty ? nil : list[s.index % list.count]
    }

    private func refresh() {
        guard let s = session, s.visible else { return }
        let action = currentAction(s)
        let list = s.source.map(actions(for:)) ?? []

        var highlighted: RadialDirection?
        if case .direction(let d)? = s.source { highlighted = d }

        let title: String
        if let action {
            title = settings.title(for: action)
        } else if s.source == nil || highlighted == .center {
            title = settings.cursorSelection ? "Move to choose" : "Press a key"
        } else {
            title = "No action"
        }
        let subtitle = list.count > 1 ? "\(s.index % list.count + 1) of \(list.count) · click to cycle" : nil
        radial.model.set(direction: highlighted,
                         centerActive: highlighted == .center && action != nil || (s.source?.isKeybind == true && action != nil),
                         title: title,
                         subtitle: subtitle,
                         symbol: action?.builtin?.symbolName ?? (action != nil ? "rectangle.dashed" : nil))

        if settings.previewEnabled, let action, let frame = engine.targetFrame(for: action, window: s.window) {
            preview.show(target: frame, from: s.window.frame, theme: settings.previewTheme)
        } else {
            preview.hide()
        }
    }

    private func end(commit: Bool) {
        guard let s = session else { return }
        s.timer?.invalidate()
        session = nil
        radial.hide()
        preview.hide()

        guard commit, s.visible, let source = s.source, let action = currentAction(s) else { return }
        let index = s.index
        engine.perform(action, on: s.window) { [weak self] window, frame in
            guard let frame else { return }
            self?.engine.cycles.record(key: source.cycleKey, windowID: window.id, index: index, frame: frame)
        }
    }

    /// Used by Settings when the trigger keys change mid-press, and on pause.
    func cancel() {
        end(commit: false)
        triggerDown = false
    }
}
