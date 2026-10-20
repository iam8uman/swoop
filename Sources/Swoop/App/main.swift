import AppKit
import SwoopCore

// Tiny command line helpers (the app itself is driven by swoop:// URLs):
//   Swoop.app/Contents/MacOS/Swoop --list      print every command
//   Swoop.app/Contents/MacOS/Swoop --version
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "--list" {
    let layouts = SettingsStore.loadFromDisk().customLayouts
    CommandParser.allCommands(customLayouts: layouts).forEach { print($0) }
    exit(0)
}
if arguments.first == "--version" {
    print("Swoop \(AppInfo.version)")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar app, no Dock icon
app.run()
