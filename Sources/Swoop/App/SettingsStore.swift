import AppKit
import Combine
import SwoopCore
import UniformTypeIdentifiers

/// Holds the live settings and saves them to UserDefaults (as JSON) whenever they change.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private static let key = "SwoopSettings"

    @Published var settings: SwoopSettings {
        didSet {
            if settings != oldValue { save() }
        }
    }

    private init() {
        settings = SettingsStore.loadFromDisk()
    }

    static func loadFromDisk() -> SwoopSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SwoopSettings.self, from: data) else {
            return SwoopSettings()
        }
        return decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    func resetAll() {
        settings = SwoopSettings()
    }

    // MARK: Import / export (share setups, back up before experimenting)

    func exportToFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Swoop Settings.json"
        panel.allowedContentTypes = [.json]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(settings).write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            settings = try JSONDecoder().decode(SwoopSettings.self, from: Data(contentsOf: url))
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
