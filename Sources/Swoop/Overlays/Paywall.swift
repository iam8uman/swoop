import AppKit
import SwiftUI
import SwoopCore

/// "Your free trial has ended" window with Buy and Restore.
struct PaywallView: View {
    @ObservedObject var manager: LicenseManager
    var onClose: () -> Void

    private var headline: String {
        switch manager.status {
        case .expired: return "Your free trial has ended"
        case .licensed: return "Thanks for buying Swoop!"
        default: return "Get Swoop for life"
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 84, height: 84)
            VStack(spacing: 6) {
                Text(headline).font(.title2.bold())
                Text(manager.status == .licensed
                     ? "Every feature is unlocked on this Mac."
                     : "Keep flicking windows into place. Pay once, use it forever.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if manager.status != .licensed {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Every layout, shortcut, screen action and stash", systemImage: "checkmark.circle.fill")
                    Label("Lifetime license, including future updates", systemImage: "checkmark.circle.fill")
                    Label("Supports an independent open-source app", systemImage: "checkmark.circle.fill")
                }
                .symbolRenderingMode(.multicolor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)

                Button {
                    manager.buy()
                } label: {
                    HStack {
                        if manager.isWorking { ProgressView().controlSize(.small) }
                        Text("Buy Swoop: \(manager.price)")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(manager.isWorking)

                HStack {
                    Button("Restore Purchase") { manager.restore() }
                    Spacer()
                    Button(manager.status == .expired ? "Not Now" : "Close", action: onClose)
                }
                .buttonStyle(.link)
            } else {
                Button("Done", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }

            if let message = manager.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(28)
        .frame(width: 400)
    }
}

final class PaywallController {
    private unowned let manager: LicenseManager
    private var window: NSWindow?

    init(manager: LicenseManager) {
        self.manager = manager
    }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: PaywallView(manager: manager) { [weak self] in self?.close() })
            let w = NSWindow(contentViewController: host)
            w.title = "Swoop"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }
}
