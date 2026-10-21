import AppKit
import Combine
import SwiftUI
import SwoopCore

enum AppInfo {
    static let name = "Swoop"
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
    static let website = URL(string: "https://swoop-mac.vercel.app")!
    static let repository = URL(string: "https://github.com/iam8uman/swoop")!
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let trigger = TriggerController()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?
    private let store = SettingsStore.shared
    private static let launchedBeforeKey = "SwoopLaunchedBefore"

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        LicenseManager.shared.start()
        setUpStatusItem()
        startWhenTrusted()

        if !UserDefaults.standard.bool(forKey: Self.launchedBeforeKey) {
            UserDefaults.standard.set(true, forKey: Self.launchedBeforeKey)
            openSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        WindowEngine.shared.animator.cancelAll()
        WindowEngine.shared.stash.unstashAll()
    }

    /// Opening Swoop again (Finder, Spotlight, Launchpad) shows Settings, since it has no Dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    // MARK: - Accessibility

    private func startWhenTrusted() {
        if AX.isTrusted(prompt: false) {
            Permission.rememberTrusted()
            startTrigger()
            return
        }
        // After an update the old Accessibility entry points at the previous build and silently
        // stops working. Clear it so macOS asks again for this build.
        if Permission.isStaleAfterUpdate {
            Permission.resetAccessibility()
        }
        _ = AX.isTrusted(prompt: true)
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard AX.isTrusted(prompt: false) else { return }
            timer.invalidate()
            Permission.rememberTrusted()
            self?.permissionTimer = nil
            self?.startTrigger()
        }
    }

    private func startTrigger() {
        if !trigger.start() {
            // Trusted but the tap still failed: usually a stale permission after rebuilding the app.
            let alert = NSAlert()
            alert.messageText = "Swoop can't watch the keyboard yet"
            alert.informativeText = """
            Open System Settings → Privacy & Security → Accessibility, remove Swoop with the − button, \
            add it again, then relaunch Swoop.
            """
            alert.addButton(withTitle: "Open Accessibility Settings")
            alert.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn { openAccessibilitySettings() }
        }
        updateStatusIcon()
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - URL scheme (swoop://...)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { run(url) }
    }

    private func run(_ url: URL) {
        let settings = store.settings
        guard let command = CommandParser.parse(url, customLayouts: settings.customLayouts) else {
            NSSound.beep()
            return
        }
        switch command {
        case .action(let ref):
            WindowEngine.shared.perform(ref)
        case .direction(let d):
            if let first = settings.actions(for: d).first { WindowEngine.shared.perform(first) }
        case .openSettings:
            openSettings()
        case .list:
            let all = CommandParser.allCommands(customLayouts: settings.customLayouts).joined(separator: "\n")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(all, forType: .string)
            let alert = NSAlert()
            alert.messageText = "Swoop commands copied"
            alert.informativeText = "Every swoop:// command is now on your clipboard. Run one with: open -g \"swoop://action/maximize\""
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    // MARK: - Settings window

    @objc func openSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView().environmentObject(store))
            let window = NSWindow(contentViewController: host)
            window.title = "Swoop Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 760, height: 600))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        updateStatusIcon()
    }

    private func updateStatusIcon() {
        statusItem?.button?.image = StatusIcon.image(active: trigger.isRunning && !trigger.isPaused)
        statusItem?.button?.toolTip = "Swoop"
    }

    /// Rebuilt every time it opens, so it always reflects the current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let settings = store.settings

        let state: String
        if !AX.isTrusted(prompt: false) {
            state = "Needs Accessibility permission"
        } else if trigger.isPaused {
            state = "Swoop is paused"
        } else {
            let keys = settings.triggerKeys.sorted { $0.rawValue < $1.rawValue }.map(\.symbol).joined(separator: " + ")
            state = "Hold \(keys) and move the mouse"
        }
        let header = NSMenuItem(title: state, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let license = LicenseManager.shared
        if !license.statusLine.isEmpty {
            let line = NSMenuItem(title: license.statusLine, action: nil, keyEquivalent: "")
            line.isEnabled = false
            menu.addItem(line)
            if license.status != .licensed {
                menu.addItem(item("Buy Swoop (\(license.price))…", #selector(showPaywall)))
            }
        }

        if !AX.isTrusted(prompt: false) {
            menu.addItem(item("Fix Accessibility Permission…", #selector(grantPermission)))
        }
        menu.addItem(.separator())

        // Every action, applied to the frontmost window.
        let actionsItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let actionsMenu = NSMenu()
        for category in ActionCategory.allCases {
            let sub = NSMenuItem(title: category.rawValue, action: nil, keyEquivalent: "")
            let subMenu = NSMenu()
            for action in category.actions {
                let a = item(action.title, #selector(runActionFromMenu(_:)))
                a.representedObject = ActionRef.builtin(action).stringValue
                a.image = NSImage(systemSymbolName: action.symbolName, accessibilityDescription: nil)
                subMenu.addItem(a)
            }
            sub.submenu = subMenu
            actionsMenu.addItem(sub)
        }
        if !settings.customLayouts.isEmpty {
            actionsMenu.addItem(.separator())
            for layout in settings.customLayouts {
                let a = item(layout.name, #selector(runActionFromMenu(_:)))
                a.representedObject = ActionRef.custom(layout.id).stringValue
                actionsMenu.addItem(a)
            }
        }
        actionsItem.submenu = actionsMenu
        menu.addItem(actionsItem)

        let pause = item(trigger.isPaused ? "Resume Swoop" : "Pause Swoop", #selector(togglePause))
        menu.addItem(pause)
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(item("About Swoop", #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(item("Quit Swoop", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func runActionFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let ref = ActionRef(string: raw) else { return }
        // The menu closes first; give focus a moment to settle back on the user's window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            WindowEngine.shared.perform(ref)
        }
    }

    @objc private func showPaywall() {
        LicenseManager.shared.showPaywall()
    }

    @objc private func togglePause() {
        trigger.isPaused.toggle()
        if trigger.isPaused { trigger.cancel() }
        updateStatusIcon()
    }

    @objc private func grantPermission() {
        Permission.resetAccessibility()
        _ = AX.isTrusted(prompt: true)
        openAccessibilitySettings()
        startWhenTrusted()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .credits: NSAttributedString(string: "Window management with a flick.\nFree and open source (MIT) by Suman Sharma."),
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Keeps the Accessibility permission working across updates.
/// Swoop builds are ad-hoc signed, so macOS treats each new build as a different app and an
/// existing "on" toggle stops applying. Clearing Swoop's own entry makes macOS ask again.
enum Permission {
    private static let key = "SwoopTrustedBuild"
    private static var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev"
    }

    static func rememberTrusted() {
        UserDefaults.standard.set(currentBuild, forKey: key)
    }

    /// Swoop was allowed before, on a different build, and isn't allowed now.
    static var isStaleAfterUpdate: Bool {
        guard let previous = UserDefaults.standard.string(forKey: key) else { return false }
        return previous != currentBuild
    }

    /// Removes Swoop's own Accessibility entry (no admin password needed).
    static func resetAccessibility() {
        guard let id = Bundle.main.bundleIdentifier else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "Accessibility", id]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            NSLog("Swoop: could not reset Accessibility permission: \(error)")
        }
    }
}

/// Menu bar icon: a ring with one highlighted slice, drawn in code so it stays crisp and template-tinted.
enum StatusIcon {
    static func image(active: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3))
            ring.lineWidth = 3
            NSColor.black.withAlphaComponent(active ? 0.45 : 0.3).setStroke()
            ring.stroke()

            if active {
                // Top-right slice, like a window being flicked into the corner.
                let center = NSPoint(x: rect.midX, y: rect.midY)
                let slice = NSBezierPath()
                slice.appendArc(withCenter: center, radius: rect.width / 2 - 3, startAngle: 22.5, endAngle: 67.5)
                slice.lineWidth = 3.4
                slice.lineCapStyle = .round
                NSColor.black.setStroke()
                slice.stroke()
            }
            let dot = NSBezierPath(ovalIn: NSRect(x: rect.midX - 2, y: rect.midY - 2, width: 4, height: 4))
            NSColor.black.setFill()
            dot.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
