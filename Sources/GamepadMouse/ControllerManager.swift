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

    func setLight(red: Float, green: Float, blue: Float) {
        controller?.light?.color = GCColor(red: red, green: green, blue: blue)
    }

    private func refresh() {
        let current = controller.flatMap { c in GCController.controllers().contains(c) ? c : nil }
        controller = current ?? GCController.controllers().first { $0.extendedGamepad != nil }
        onChange?()
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
