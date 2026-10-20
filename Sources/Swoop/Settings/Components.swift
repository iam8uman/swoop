import AppKit
import SwiftUI
import SwoopCore

/// A menu of every action, grouped like the docs, plus the user's custom layouts.
struct ActionMenu: View {
    let customLayouts: [CustomLayout]
    var title: String = "Add Action"
    let onPick: (ActionRef) -> Void

    var body: some View {
        Menu {
            ForEach(ActionCategory.allCases, id: \.self) { category in
                Menu(category.rawValue) {
                    ForEach(category.actions) { action in
                        Button {
                            onPick(.builtin(action))
                        } label: {
                            Label(action.title, systemImage: action.symbolName)
                        }
                    }
                }
            }
            if !customLayouts.isEmpty {
                Divider()
                Menu("Custom Layouts") {
                    ForEach(customLayouts) { layout in
                        Button(layout.name) { onPick(.custom(layout.id)) }
                    }
                }
            }
        } label: {
            Label(title, systemImage: "plus")
        }
        .fixedSize()
    }
}

/// Edits a list of actions. More than one makes a cycle: repeat the input to step through them.
struct ActionListEditor: View {
    @Binding var actions: [ActionRef]
    let customLayouts: [CustomLayout]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if actions.isEmpty {
                Text("No action")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(actions.enumerated()), id: \.offset) { index, ref in
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Label(ref.title(customLayouts: customLayouts),
                          systemImage: ref.builtin?.symbolName ?? "rectangle.dashed")
                    Spacer()
                    Button {
                        actions.swapAt(index, index - 1)
                    } label: { Image(systemName: "chevron.up") }
                        .disabled(index == 0)
                    Button {
                        actions.swapAt(index, index + 1)
                    } label: { Image(systemName: "chevron.down") }
                        .disabled(index == actions.count - 1)
                    Button(role: .destructive) {
                        actions.remove(at: index)
                    } label: { Image(systemName: "trash") }
                }
                .buttonStyle(.borderless)
                .padding(.vertical, 2)
            }
            HStack {
                ActionMenu(customLayouts: customLayouts) { actions.append($0) }
                if actions.count > 1 {
                    Text("Cycle: repeat the key or click to step through these.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Click, then press a key (with optional ⌃⌥⇧⌘). Records the key used together with the trigger.
struct KeyRecorder: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: ModifierKeys
    let trigger: Set<TriggerKey>
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Press a key…" : modifiers.symbols + KeyNames.name(for: keyCode))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(minWidth: 110)
        }
        .buttonStyle(.bordered)
        .tint(recording ? .accentColor : nil)
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == KeyNames.escape {
                stop()
                return nil
            }
            keyCode = event.keyCode
            // Modifiers that belong to the trigger itself aren't part of the shortcut.
            let flags = UInt64(event.cgEvent?.flags.rawValue ?? UInt64(event.modifierFlags.rawValue))
            modifiers = TriggerKey.extraModifiers(flags: flags, trigger: trigger)
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}

/// A labelled slider with its value shown.
struct ValueSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var format: (Double) -> String = { "\(Int($0.rounded()))" }

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $value, in: range, step: step)
                    .frame(minWidth: 180)
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }
}

/// Little screen thumbnail showing where a layout lands.
struct LayoutThumbnail: View {
    let unit: CGRect
    var color: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.8))
                    .frame(width: geo.size.width * unit.width - 2, height: geo.size.height * unit.height - 2)
                    .offset(x: geo.size.width * unit.minX + 1, y: geo.size.height * unit.minY + 1)
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
    }
}
