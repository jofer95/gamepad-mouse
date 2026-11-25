import AppKit
import SwiftUI

/// A button that shows a shortcut and, when clicked, records the next one typed.
/// With `allowModifiersOnly`, pressing and releasing just modifiers (like ⇧⌃) also counts,
/// which is what push-to-talk shortcuts use.
struct ShortcutRecorder: View {
    let key: String?
    let modifiers: [String]
    let allowModifiersOnly: Bool
    let onRecord: (_ key: String?, _ modifiers: [String]) -> Void

    @State private var recording = false
    @State private var monitor: Any?
    @State private var peakModifiers: NSEvent.ModifierFlags = []

    var body: some View {
        Button(action: { recording ? stop() : start() }) {
            Text(label)
                .frame(minWidth: 110)
                .foregroundStyle(recording ? Color.accentColor : (isEmpty ? .secondary : .primary))
        }
        .help(allowModifiersOnly
              ? tr("Click, then press the keys to hold, like ⇧⌃ for Wispr Flow", "Haz clic y presiona las teclas a mantener, por ejemplo ⇧⌃ para Wispr Flow")
              : tr("Click, then press the shortcut", "Haz clic y presiona el atajo"))
        .onDisappear(perform: stop)
    }

    private var isEmpty: Bool { key == nil && modifiers.isEmpty }

    private var label: String {
        if recording { return tr("Press the keys…", "Presiona las teclas…") }
        return isEmpty ? tr("Record shortcut", "Grabar atajo") : KeyCodes.display(key: key, modifiers: modifiers)
    }

    private func start() {
        peakModifiers = []
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
            return nil // Swallow it, so ⌘W records instead of closing the window.
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }

    private func handle(_ event: NSEvent) {
        let relevant: NSEvent.ModifierFlags = [.control, .option, .shift, .command, .function]
        let flags = event.modifierFlags.intersection(relevant)
        switch event.type {
        case .keyDown:
            guard let name = KeyCodes.name(for: CGKeyCode(event.keyCode)) else { return }
            // Arrows and F-keys report the fn flag on their own, so it's not part of the shortcut.
            finish(key: name, modifiers: names(for: flags.subtracting(.function)))
        case .flagsChanged:
            if flags.isEmpty {
                if allowModifiersOnly && !peakModifiers.isEmpty {
                    finish(key: nil, modifiers: names(for: peakModifiers))
                }
            } else {
                peakModifiers.formUnion(flags)
            }
        default:
            break
        }
    }

    private func finish(key: String?, modifiers: [String]) {
        stop()
        onRecord(key, modifiers)
    }

    private func names(for flags: NSEvent.ModifierFlags) -> [String] {
        var names: [String] = []
        if flags.contains(.control) { names.append("ctrl") }
        if flags.contains(.option) { names.append("option") }
        if flags.contains(.shift) { names.append("shift") }
        if flags.contains(.command) { names.append("cmd") }
        if flags.contains(.function) { names.append("fn") }
        return names
    }
}
