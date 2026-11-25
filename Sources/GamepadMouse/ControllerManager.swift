import Foundation
import GameController

/// Tracks the connected controller and reads its state.
final class ControllerManager {
    private(set) var controller: GCController?
    var onChange: (() -> Void)?
    private var observers: [NSObjectProtocol] = []
    private let dualSenseBattery = DualSenseBattery()

    init() {
        dualSenseBattery.onChange = { [weak self] in self?.onChange?() }

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

    var batteryDescription: String? {
        guard controller != nil else { return nil }
        // macOS reports the DualSense over Bluetooth as unknown with level 0, which isn't a
        // reading, so ask the controller itself first.
        if let reading = dualSenseBattery.reading {
            switch reading.state {
            case .charging: return "🔋 \(reading.percent)% (cargando)"
            case .full: return "🔋 100% (cargada)"
            case .error: return "🔋 error de carga"
            case .discharging:
                return reading.percent <= 15 ? "🪫 \(reading.percent)% (batería baja)" : "🔋 \(reading.percent)%"
            }
        }
        guard let battery = controller?.battery, battery.batteryState != .unknown else { return nil }
        let percent = Int((battery.batteryLevel * 100).rounded())
        switch battery.batteryState {
        case .charging: return "🔋 \(percent)% (cargando)"
        case .full: return "🔋 100% (cargada)"
        default: return "🔋 \(percent)%"
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
