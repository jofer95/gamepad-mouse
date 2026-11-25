import CoreHaptics
import Foundation
import GameController

/// Tracks the connected controller and reads its state.
final class ControllerManager {
    private(set) var controller: GCController?
    var onChange: (() -> Void)?
    private var observers: [NSObjectProtocol] = []
    private let dualSense = DualSenseHID()

    init() {
        dualSense.onBatteryChange = { [weak self] in self?.onChange?() }
        dualSense.onAttach = { [weak self] in self?.resendLight() }
        // Sending the light again is the output report that wakes the full report back up.
        dualSense.onShortReports = { [weak self] in self?.resendLight() }

        // Without this, macOS only delivers controller input while our app is frontmost,
        // and a menu bar app never is.
        GCController.shouldMonitorBackgroundEvents = true

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        })
        refresh()
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    var name: String? { controller?.vendorName ?? controller?.productCategory }

    /// The fingers on the DualSense touchpad: none, one or two.
    var touches: [DualSenseHID.Touch] { controller == nil ? [] : dualSense.touches }

    /// Whether the DualSense mute button is held.
    var muteDown: Bool { controller != nil && dualSense.muteDown }

    /// The DualSense's average rotation since the last call, in degrees per second.
    func takeRotation() -> DualSenseHID.Rotation? { dualSense.takeRotation() }

    // MARK: Haptics

    private var hapticEngine: CHHapticEngine?
    private weak var hapticController: GCController?

    /// Short pulses in the controller, to confirm something without looking at the screen.
    func playHaptic(pulses: Int) {
        guard let controller, pulses > 0 else { return }
        do {
            if hapticEngine == nil || hapticController !== controller {
                hapticEngine = controller.haptics?.createEngine(withLocality: .default)
                hapticController = controller
                // The engine stops after a while unused; let it, and start it again on demand.
                hapticEngine?.isAutoShutdownEnabled = true
            }
            guard let engine = hapticEngine else { return }
            try engine.start()
            let events = (0..<pulses).map { index in
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6),
                ], relativeTime: Double(index) * 0.14)
            }
            try engine.makePlayer(with: CHHapticPattern(events: events, parameters: [])).start(atTime: CHHapticTimeImmediate)
        } catch {
            NSLog("GamepadMouse: couldn't play haptics: \(error)")
        }
    }

    var batteryDescription: String? {
        guard controller != nil else { return nil }
        // macOS reports the DualSense over Bluetooth as unknown with level 0, which isn't a
        // reading, so ask the controller itself first.
        if let reading = dualSense.battery {
            switch reading.state {
            case .charging: return "⚡️ " + tr("Charging", "Cargando")
            case .full: return "🔋 " + tr("Battery full", "Batería completa")
            case .error: return "⚠️ " + tr("Charging error", "Error de carga")
            case .discharging: return Self.describe(level: reading.level)
            }
        }
        guard let battery = controller?.battery, battery.batteryState != .unknown else { return nil }
        switch battery.batteryState {
        case .charging: return "⚡️ " + tr("Charging", "Cargando")
        case .full: return "🔋 " + tr("Battery full", "Batería completa")
        default: return Self.describe(level: Int(battery.batteryLevel * 10))
        }
    }

    /// The controller only reports tenths, so the menu says it in words, not a fake percent.
    private static func describe(level: Int) -> String {
        switch level {
        case 8...: return "🔋 " + tr("Battery high", "Batería alta")
        case 6...7: return "🔋 " + tr("Battery medium-high", "Batería alta media")
        case 4...5: return "🔋 " + tr("Battery medium", "Batería media")
        case 2...3: return "🔋 " + tr("Battery medium-low", "Batería media baja")
        default: return "🪫 " + tr("Battery low", "Batería baja")
        }
    }

    /// Whether the battery is in its lowest step and not charging.
    var batteryIsLow: Bool {
        guard controller != nil else { return false }
        if let reading = dualSense.battery { return reading.state == .discharging && reading.level < 2 }
        guard let battery = controller?.battery else { return false }
        return battery.batteryState == .discharging && battery.batteryLevel < 0.2
    }

    /// Whether the light bar can follow an animation without flooding macOS.
    var canAnimateLight: Bool { controller != nil && dualSense.canSetLight }

    private func resendLight() {
        sentLight = nil
        onChange?()
    }

    private var sentLight: LightColor?
    private weak var sentLightController: GCController?

    /// Sets the light bar, only when the color changes. A DualSense gets it straight through its
    /// HID output report; GameController's light can stop reaching it and stay on one color.
    /// Other controllers go through GameController, where every write costs macOS's controller
    /// service a new object, so a steady stream of them can jam it.
    func setLight(_ color: LightColor) {
        guard let controller else { return }
        if controller === sentLightController, let sent = sentLight,
           abs(sent.red - color.red) < 0.004, abs(sent.green - color.green) < 0.004, abs(sent.blue - color.blue) < 0.004 {
            return
        }
        if !dualSense.setLight(color) {
            guard let light = controller.light else { return }
            light.color = GCColor(red: Float(color.red), green: Float(color.green), blue: Float(color.blue))
        }
        sentLight = color
        sentLightController = controller
    }

    private func refresh() {
        let current = controller.flatMap { c in GCController.controllers().contains(c) ? c : nil }
        controller = current ?? GCController.controllers().first { $0.extendedGamepad != nil }
        onChange?()
        // A write right after connecting can be lost, mostly over Bluetooth: send the light again
        // once the controller has settled.
        for delay in [1.0, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.resendLight() }
        }
    }

    /// The pressed state of every button, read from the current controller.
    func readButtons() -> [PadButton: Bool]? {
        guard let pad = controller?.extendedGamepad else { return nil }
        var state: [PadButton: Bool] = [
            .cross: pad.buttonA.isPressed,
            .circle: pad.buttonB.isPressed,
            .square: pad.buttonX.isPressed,
            .triangle: pad.buttonY.isPressed,
            .l1: pad.leftShoulder.isPressed,
            .r1: pad.rightShoulder.isPressed,
            .l2: pad.leftTrigger.isPressed,
            .r2: pad.rightTrigger.isPressed,
            .l3: pad.leftThumbstickButton?.isPressed ?? false,
            .r3: pad.rightThumbstickButton?.isPressed ?? false,
            .dpadUp: pad.dpad.up.isPressed,
            .dpadDown: pad.dpad.down.isPressed,
            .dpadLeft: pad.dpad.left.isPressed,
            .dpadRight: pad.dpad.right.isPressed,
            .options: pad.buttonMenu.isPressed,
            .create: pad.buttonOptions?.isPressed ?? false,
            .ps: pad.buttonHome?.isPressed ?? false,
        ]
        if let dualSense = pad as? GCDualSenseGamepad {
            state[.touchpad] = dualSense.touchpadButton.isPressed
        } else if let dualShock = pad as? GCDualShockGamepad {
            state[.touchpad] = dualShock.touchpadButton.isPressed
        }
        return state
    }

    /// Stick positions, x right and y up, each in -1...1.
    func readSticks() -> (left: CGPoint, right: CGPoint)? {
        guard let pad = controller?.extendedGamepad else { return nil }
        return (CGPoint(x: Double(pad.leftThumbstick.xAxis.value), y: Double(pad.leftThumbstick.yAxis.value)),
                CGPoint(x: Double(pad.rightThumbstick.xAxis.value), y: Double(pad.rightThumbstick.yAxis.value)))
    }
}
