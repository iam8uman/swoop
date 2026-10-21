import AppKit
import ServiceManagement
import SwiftUI
import SwoopCore
import Combine
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            TriggerTab().tabItem { Label("Trigger", systemImage: "option") }
            RadialTab().tabItem { Label("Radial Menu", systemImage: "circle.circle") }
            PreviewTab().tabItem { Label("Preview", systemImage: "rectangle.dashed") }
            KeybindsTab().tabItem { Label("Keybinds", systemImage: "keyboard") }
            CustomLayoutsTab().tabItem { Label("Layouts", systemImage: "square.grid.3x3.square") }
            StashTab().tabItem { Label("Stash", systemImage: "sidebar.right") }
            LicenseTab().tabItem { Label("License", systemImage: "checkmark.seal") }
            AboutTab().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(minWidth: 760, minHeight: 600)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @EnvironmentObject var store: SettingsStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var trusted = AX.isTrusted(prompt: false)
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                HowToCard(triggerKeys: store.settings.triggerKeys)
                if !trusted {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Swoop needs Accessibility permission to move windows.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Already switched on? After an update macOS needs it again. Click Fix, then turn Swoop on.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Fix…") {
                            Permission.resetAccessibility()
                            _ = AX.isTrusted(prompt: true)
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch Swoop at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                            NSSound.beep()
                        }
                    }
            }

            Section("Windows") {
                ValueSlider(title: "Padding", value: $store.settings.padding, range: 0...40)
                ValueSlider(title: "Resize & move step", value: $store.settings.sizeStep, range: 10...200, step: 5)
                Toggle("Animate windows", isOn: $store.settings.animateWindows)
                if store.settings.animateWindows {
                    ValueSlider(title: "Animation speed", value: $store.settings.animationDuration,
                                range: 0.08...0.4, step: 0.01, format: { String(format: "%.2fs", $0) })
                }
                Toggle("Move the cursor along when a window changes screen", isOn: $store.settings.moveCursorWithWindow)
                Toggle("Haptic feedback on trackpads", isOn: $store.settings.hapticFeedback)
            }

            Section {
                ExcludedAppsEditor(bundleIDs: $store.settings.excludedBundleIDs)
            } header: {
                Text("Ignored apps")
            } footer: {
                Text("Swoop won't move windows of these apps.")
            }

            Section("Settings") {
                HStack {
                    Button("Export…") { store.exportToFile() }
                    Button("Import…") { store.importFromFile() }
                    Spacer()
                    Button("Reset Everything…", role: .destructive) { confirmReset = true }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            trusted = AX.isTrusted(prompt: false)
        }
        .confirmationDialog("Reset all Swoop settings to their defaults?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { store.resetAll() }
        }
    }
}

private struct HowToCard: View {
    let triggerKeys: Set<TriggerKey>

    var body: some View {
        let trigger = triggerKeys.sorted { $0.rawValue < $1.rawValue }.map(\.title).joined(separator: " + ")
        VStack(alignment: .leading, spacing: 8) {
            Text("How to use Swoop").font(.headline)
            Label("Hold **\(trigger)** and move the mouse toward where the window should go. Let go to apply.",
                  systemImage: "cursorarrow.motionlines")
            Label("While holding it, click to cycle (½ → ⅓ → ⅔), or press a key: ← → ↑ ↓, ↩ maximize, C centre.",
                  systemImage: "keyboard")
            Label("Esc or right-click cancels. Typing normally with the key held is never blocked.",
                  systemImage: "xmark.circle")
        }
        .padding(.vertical, 4)
    }
}

private struct ExcludedAppsEditor: View {
    @Binding var bundleIDs: [String]

    var body: some View {
        VStack(alignment: .leading) {
            if bundleIDs.isEmpty {
                Text("None").foregroundStyle(.secondary)
            }
            ForEach(bundleIDs, id: \.self) { id in
                HStack {
                    Text(appName(for: id))
                    Text(id).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) {
                        bundleIDs.removeAll { $0 == id }
                    } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                }
            }
            Button("Add App…", action: addApp)
        }
    }

    private func appName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !bundleIDs.contains(id) { bundleIDs.append(id) }
        }
    }
}

// MARK: - Trigger

private struct TriggerTab: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                ForEach(TriggerKey.allCases) { key in
                    Toggle(key.title, isOn: Binding(
                        get: { store.settings.triggerKeys.contains(key) },
                        set: { on in
                            if on {
                                store.settings.triggerKeys.insert(key)
                            } else if store.settings.triggerKeys.count > 1 {
                                store.settings.triggerKeys.remove(key)
                            }
                        }
                    ))
                }
            } header: {
                Text("Trigger key")
            } footer: {
                Text("Pick one key, or several to require them together. Left and right keys are separate. With Left ⌥, Swoop's shortcut keys (arrows, C, F…) act on windows while it's held; pick Right ⌥ or 🌐 if you'd rather keep ⌥ for typing. Using 🌐? Set System Settings → Keyboard → “Press 🌐 key to” → Do Nothing. Want Caps Lock? Remap it to Control in System Settings → Keyboard → Modifier Keys, then choose Right Control here — or use Hyperkey / Karabiner-Elements.")
            }

            Section("Behaviour") {
                ValueSlider(title: "Hold before the menu appears", value: $store.settings.triggerDelay,
                            range: 0...0.6, step: 0.05, format: { String(format: "%.2fs", $0) })
                Toggle("Pick directions with the cursor", isOn: $store.settings.cursorSelection)
                if store.settings.cursorSelection {
                    ValueSlider(title: "Dead zone", value: $store.settings.deadZone, range: 4...60,
                                format: { "\(Int($0)) pt" })
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Radial menu

private struct RadialTab: View {
    @EnvironmentObject var store: SettingsStore
    @StateObject private var demo = RadialModel()
    @State private var selected: RadialDirection = .right

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Form {
                Section("Appearance") {
                    Toggle("Show the radial menu", isOn: $store.settings.radialMenuEnabled)
                    Picker("Shape", selection: $store.settings.radialTheme.shape) {
                        ForEach(RadialShape.allCases) { Text($0.title).tag($0) }
                    }
                    ValueSlider(title: "Size", value: $store.settings.radialTheme.diameter, range: 70...200)
                    ValueSlider(title: "Ring thickness", value: $store.settings.radialTheme.thickness, range: 8...50)
                    if store.settings.radialTheme.shape == .roundedSquare {
                        ValueSlider(title: "Corner radius", value: $store.settings.radialTheme.cornerRadius, range: 0...80)
                    }
                    Toggle("Use macOS accent colour", isOn: $store.settings.radialTheme.useAccentColor)
                    if !store.settings.radialTheme.useAccentColor {
                        ColorPicker("Colour", selection: hexColorBinding($store.settings.radialTheme.colorHex), supportsOpacity: false)
                    }
                    Toggle("Show action name", isOn: $store.settings.radialTheme.showLabel)
                }

                Section {
                    Picker("Direction", selection: $selected) {
                        ForEach(RadialDirection.allCases) { d in
                            Text("\(d.arrow)  \(d.title)").tag(d)
                        }
                    }
                    ActionListEditor(actions: Binding(
                        get: { store.settings.actions(for: selected) },
                        set: { store.settings.radialActions[selected] = $0 }
                    ), customLayouts: store.settings.customLayouts)
                } header: {
                    Text("Directions")
                } footer: {
                    Text("Centre is where the cursor starts. Leave it empty so letting go without moving does nothing.")
                }

                Section {
                    Button("Restore Default Directions") {
                        store.settings.radialActions = SwoopSettings.defaultRadialActions
                    }
                }
            }
            .formStyle(.grouped)

            VStack {
                Text("Preview").font(.caption).foregroundStyle(.secondary)
                RadialMenuView(model: demo)
                    .padding(24)
                    .background(
                        LinearGradient(colors: [.purple.opacity(0.35), .blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            }
            .frame(width: 260)
            .padding(.top, 20)
            .padding(.trailing, 16)
        }
        .onAppear(perform: updateDemo)
        .onChange(of: selected) { _ in updateDemo() }
        .onChange(of: store.settings) { _ in updateDemo() }
    }

    private func updateDemo() {
        let s = store.settings
        demo.theme = s.radialTheme
        let list = s.actions(for: selected)
        let first = list.first
        demo.set(direction: selected,
                 centerActive: selected == .center && first != nil,
                 title: first.map { s.title(for: $0) } ?? "No action",
                 subtitle: list.count > 1 ? "1 of \(list.count) · click to cycle" : nil,
                 symbol: first?.builtin?.symbolName)
    }
}

// MARK: - Preview

private struct PreviewTab: View {
    @EnvironmentObject var store: SettingsStore
    @StateObject private var demo = PreviewModel()

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Form {
                Section("Preview") {
                    Toggle("Show where the window will go", isOn: $store.settings.previewEnabled)
                    ValueSlider(title: "Padding", value: $store.settings.previewTheme.padding, range: 0...40)
                    ValueSlider(title: "Corner radius", value: $store.settings.previewTheme.cornerRadius, range: 0...40)
                    ValueSlider(title: "Border width", value: $store.settings.previewTheme.borderWidth, range: 0...12)
                    ValueSlider(title: "Fill", value: $store.settings.previewTheme.fillOpacity, range: 0...0.6,
                                step: 0.02, format: { "\(Int(($0 * 100).rounded()))%" })
                    Toggle("Use macOS accent colour", isOn: $store.settings.previewTheme.useAccentColor)
                    if !store.settings.previewTheme.useAccentColor {
                        ColorPicker("Colour", selection: hexColorBinding($store.settings.previewTheme.colorHex), supportsOpacity: false)
                    }
                }
            }
            .formStyle(.grouped)

            VStack {
                Text("Preview").font(.caption).foregroundStyle(.secondary)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.indigo.opacity(0.35), .teal.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    PreviewView(model: demo)
                        .frame(width: 120)
                }
                .frame(width: 240, height: 160)
            }
            .padding(.top, 20)
            .padding(.trailing, 16)
        }
        .onAppear { demo.theme = store.settings.previewTheme }
        .onChange(of: store.settings.previewTheme) { demo.theme = $0 }
    }
}

// MARK: - Keybinds

private struct KeybindsTab: View {
    @EnvironmentObject var store: SettingsStore
    @State private var editing: Keybind?

    var body: some View {
        let trigger = store.settings.triggerKeys.sorted { $0.rawValue < $1.rawValue }.map(\.symbol).joined(separator: "+")
        VStack(alignment: .leading, spacing: 0) {
            Text("Hold the trigger (\(trigger)) and press a key. Several actions = a cycle: press again for the next one.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding([.horizontal, .top], 20)
                .padding(.bottom, 8)

            List {
                ForEach(store.settings.keybinds) { bind in
                    HStack {
                        Text("\(trigger) + \(bind.shortcutLabel)")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .frame(width: 150, alignment: .leading)
                        Text(bind.actions.map { store.settings.title(for: $0) }.joined(separator: " → "))
                            .lineLimit(1)
                            .foregroundStyle(bind.actions.isEmpty ? .secondary : .primary)
                        Spacer()
                        Button("Edit") { editing = bind }
                        Button(role: .destructive) {
                            store.settings.keybinds.removeAll { $0.id == bind.id }
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                Button {
                    editing = Keybind(keyCode: 0, actions: [])
                } label: { Label("Add Keybind", systemImage: "plus") }
                Spacer()
                Button("Restore Defaults") { store.settings.keybinds = SwoopSettings.defaultKeybinds }
            }
            .padding(16)
        }
        .sheet(item: $editing) { bind in
            KeybindEditor(original: bind) { updated in
                if let i = store.settings.keybinds.firstIndex(where: { $0.id == updated.id }) {
                    store.settings.keybinds[i] = updated
                } else {
                    store.settings.keybinds.append(updated)
                }
            }
            .environmentObject(store)
        }
    }
}

private struct KeybindEditor: View {
    @EnvironmentObject var store: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var bind: Keybind
    let onSave: (Keybind) -> Void

    init(original: Keybind, onSave: @escaping (Keybind) -> Void) {
        _bind = State(initialValue: original)
        self.onSave = onSave
    }

    private var conflict: Keybind? {
        store.settings.keybinds.first {
            $0.id != bind.id && $0.keyCode == bind.keyCode && $0.modifiers == bind.modifiers
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keybind").font(.title3.bold())
            HStack {
                Text("Trigger +")
                KeyRecorder(keyCode: $bind.keyCode, modifiers: $bind.modifiers, trigger: store.settings.triggerKeys)
            }
            if let conflict {
                Label("Already used by \(conflict.actions.map { store.settings.title(for: $0) }.joined(separator: ", ")).",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
            Divider()
            ActionListEditor(actions: $bind.actions, customLayouts: store.settings.customLayouts)
            Spacer()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(bind)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(bind.actions.isEmpty || conflict != nil)
            }
        }
        .padding(24)
        .frame(width: 520, height: 440)
    }
}

// MARK: - Custom layouts

private struct CustomLayoutsTab: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                if store.settings.customLayouts.isEmpty {
                    Text("Make your own spots, like a centred writing column or a 70% left panel. Use them in directions, keybinds, the menu bar, or swoop://custom/<name>.")
                        .foregroundStyle(.secondary)
                }
                ForEach($store.settings.customLayouts) { $layout in
                    HStack(alignment: .top, spacing: 16) {
                        LayoutThumbnail(unit: layout.unitRect)
                            .frame(width: 110)
                        VStack(alignment: .leading) {
                            HStack {
                                TextField("Name", text: $layout.name)
                                Button(role: .destructive) {
                                    let id = layout.id
                                    // Deferred so the bound row isn't removed while SwiftUI is still reading it.
                                    DispatchQueue.main.async { store.settings.customLayouts.removeAll { $0.id == id } }
                                } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless)
                            }
                            percentSlider("X", $layout.x)
                            percentSlider("Y", $layout.y)
                            percentSlider("Width", $layout.width)
                            percentSlider("Height", $layout.height)
                        }
                    }
                    .padding(.vertical, 6)
                }
                Button {
                    store.settings.customLayouts.append(
                        CustomLayout(name: "Layout \(store.settings.customLayouts.count + 1)", x: 0.15, y: 0, width: 0.7, height: 1)
                    )
                } label: { Label("Add Layout", systemImage: "plus") }
            } header: {
                Text("Custom layouts")
            }
        }
        .formStyle(.grouped)
    }

    private func percentSlider(_ title: String, _ value: Binding<Double>) -> some View {
        ValueSlider(title: title, value: value, range: 0...1, step: 0.01, format: { "\(Int(($0 * 100).rounded()))%" })
    }
}

// MARK: - Stash

private struct StashTab: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Text("Stash tucks a window behind the left or right edge of the screen, leaving a thin sliver. Push the cursor against that edge to slide it back out; move away and it tucks itself in again. Default keys: trigger + , (left) and . (right), / to unstash.")
                    .foregroundStyle(.secondary)
                ValueSlider(title: "Visible sliver", value: $store.settings.stashPeek, range: 2...60, format: { "\(Int($0)) pt" })
                Toggle("Reveal when the cursor touches the edge", isOn: $store.settings.stashRevealOnHover)
            } header: {
                Text("Stash")
            } footer: {
                Text("Edges that touch another display can't be used for stashing; the window would just appear there.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - License

private struct LicenseTab: View {
    @ObservedObject private var license = LicenseManager.shared

    var body: some View {
        Form {
            Section {
                switch license.status {
                case .free:
                    Label("Swoop is free in this build.", systemImage: "gift")
                case .licensed:
                    Label("Lifetime license active on this Mac. Thank you!", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                case .trial(let days):
                    Label(days == 1 ? "Free trial: last day" : "Free trial: \(days) days left", systemImage: "clock")
                case .expired:
                    Label("Your free trial has ended.", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("License")
            } footer: {
                if license.status != .free {
                    Text("One-time purchase of \(license.price). Includes future updates.")
                }
            }

            if license.licensingEnabled && license.status != .licensed {
                Section {
                    HStack {
                        Button("Buy Swoop (\(license.price))") { license.buy() }
                            .buttonStyle(.borderedProminent)
                            .disabled(license.isWorking)
                        Button("Restore Purchase") { license.restore() }
                            .disabled(license.isWorking)
                        if license.isWorking { ProgressView().controlSize(.small) }
                    }
                    if let message = license.message {
                        Text(message).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { license.refresh() }
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Swoop").font(.largeTitle.bold())
            Text("Version \(AppInfo.version)").foregroundStyle(.secondary)
            Text("Window management with a flick of the mouse.")
            HStack(spacing: 16) {
                Link("Website", destination: AppInfo.website)
                Link("Source code", destination: AppInfo.repository)
                Link("Report a bug", destination: AppInfo.repository.appendingPathComponent("issues"))
            }
            Divider().frame(width: 320)
            Text("Free and open source under the MIT License.\nMade by Suman Sharma (@iam8uman on GitHub).")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Inspired by radial window managers like Loop. Swoop is an independent implementation.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
