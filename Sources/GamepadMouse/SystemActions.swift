import AppKit

/// Mission Control and its app windows view.
enum SystemActions {
    private static let missionControl = URL(fileURLWithPath: "/System/Applications/Mission Control.app")

    /// Shows every open window, or closes Mission Control if it's already showing.
    static func showMissionControl() {
        NSWorkspace.shared.openApplication(at: missionControl, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Shows the windows of the frontmost app (App Exposé) through its system shortcut, ⌃↓.
    /// Launching Mission Control with an argument for this doesn't work.
    static func showAppWindows(using synth: InputSynthesizer) {
        if let down = KeyCodes.byName["down"] { synth.tap(key: down, modifiers: ["ctrl"]) }
    }
}
