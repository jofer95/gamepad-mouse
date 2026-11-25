import Foundation
import QuartzCore

/// Polls the controller 120 times a second and turns its state into mouse and keyboard events.
final class Engine {
    private let controllers: ControllerManager
    private let synth = InputSynthesizer()
    private var timer: Timer?
    private var lastTick = CACurrentMediaTime()

    var config: Config {
        // Only a mapping change lets go of held buttons: a slider dragged with a
        // controller click must keep its click while the settings change under it.
        didSet { if config.activeTheme != oldValue.activeTheme { releaseAll() } }
    }

    var enabled = true {
        didSet {
            guard enabled != oldValue else { return }
            releaseAll()
            updateLight()
            onEnabledChange?()
        }
    }

    var onEnabledChange: (() -> Void)?
    /// Called with the buttons held whenever that set changes, even while paused.
    var onPressedChange: ((Set<PadButton>) -> Void)?
    var onNextTheme: (() -> Void)?

    private var pressed: Set<PadButton> = []
    private var reportedPressed: Set<PadButton> = []
    private var lastTouch: DualSenseHID.Touch?
    /// Finger spread at the last zoom step, while two fingers are down.
    private var pinchDistance: Double?
    /// Set by a pinch until every finger lifts.
    private var waitingForLift = false
    /// Whether a smooth pinch gesture has begun and still needs its end.
    private var pinchGestureActive = false
    /// The action each held button started, so its release matches even if the config changes.
    private var active: [PadButton: Action] = [:]
    private var nextRepeat: [PadButton: CFTimeInterval] = [:]

    private let repeatDelay: CFTimeInterval = 0.4
    private let repeatInterval: CFTimeInterval = 0.05

    init(controllers: ControllerManager, config: Config) {
        self.controllers = controllers
        self.config = config
    }

    func start() {
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.tick() }
        // .common keeps it running while the status bar menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        updateLight()
    }

    func updateLight() {
        if enabled {
            controllers.setLight(red: 0.0, green: 0.35, blue: 1.0)
        } else {
            controllers.setLight(red: 1.0, green: 0.35, blue: 0.0)
        }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 0.05)
        lastTick = now

        guard let buttons = controllers.readButtons(), let sticks = controllers.readSticks() else {
            if !pressed.isEmpty {
                releaseAll()
                pressed.removeAll()
                reportPressed()
            }
            return
        }

        for button in PadButton.allCases {
            let isDown = buttons[button] ?? false
            let wasDown = pressed.contains(button)
            if isDown && !wasDown {
                pressed.insert(button)
                press(button, now: now)
            } else if !isDown && wasDown {
                pressed.remove(button)
                release(button)
            } else if isDown, let due = nextRepeat[button], now >= due, let action = active[button] {
                perform(action)
                nextRepeat[button] = now + repeatInterval
            }
        }
        reportPressed()

        guard enabled else {
            resetTouchpad()
            return
        }
        let settings = config.settings
        let precision = active.values.contains { $0.type == .precision } ? settings.precisionFactor : 1.0
        let pointerStick = settings.pointerStick == "right" ? sticks.right : sticks.left
        let scrollStick = settings.pointerStick == "right" ? sticks.left : sticks.right

        if let v = shaped(pointerStick, curve: settings.pointerCurve) {
            let speed = settings.pointerMaxSpeed * precision * dt
            // Screen y grows downward, the stick's y grows upward.
            synth.movePointer(dx: v.x * speed, dy: -v.y * speed)
        }
        if let v = shaped(scrollStick, curve: settings.scrollCurve) {
            let speed = settings.scrollMaxSpeed * precision * dt
            let vertical = settings.invertScrollVertical ? -v.y : v.y
            let horizontal = settings.invertScrollHorizontal ? -v.x : v.x
            synth.scroll(dx: horizontal * speed, dy: vertical * speed)
        }

        if config.activeTheme.touchpadMode == .pointer {
            handleTouchpad(dt: dt, precision: precision)
        } else {
            resetTouchpad()
        }
    }

    /// One finger moves the pointer; two fingers zoom by spreading or pinching.
    private func handleTouchpad(dt: Double, precision: Double) {
        let touches = controllers.touches
        switch touches.count {
        case 0:
            resetTouchpad()
        case 1:
            endPinch()
            // After a pinch, the finger left on the touchpad shouldn't move the pointer.
            if waitingForLift { return }
            moveWithTouchpad(touches[0], dt: dt, precision: precision)
        default:
            lastTouch = nil
            waitingForLift = true
            let distance = hypot(Double(touches[0].x - touches[1].x), Double(touches[0].y - touches[1].y))
            if config.settings.smoothZoom {
                zoomSmoothly(to: distance)
            } else {
                zoomInSteps(to: distance)
            }
        }
    }

    private func resetTouchpad() {
        endPinch()
        lastTouch = nil
        waitingForLift = false
    }

    private func endPinch() {
        if pinchGestureActive {
            synth.magnify(0, phase: .ended)
            pinchGestureActive = false
        }
        pinchDistance = nil
    }

    /// Streams a trackpad pinch gesture that follows the fingers, for a continuous zoom.
    private func zoomSmoothly(to distance: Double) {
        guard let last = pinchDistance else {
            pinchDistance = distance
            return
        }
        let change = distance - last
        // Ignore sensor jitter; small moves add up until they count.
        guard abs(change) >= 3 else { return }
        if !pinchGestureActive {
            synth.magnify(0, phase: .began)
            pinchGestureActive = true
        }
        // Spreading the fingers across about half the touchpad doubles the zoom at the default.
        synth.magnify(change / 960 * config.settings.pinchSensitivity, phase: .changed)
        pinchDistance = distance
    }

    /// Sends one zoom step (⌘= or ⌘-) each time the fingers spread or close by a set distance,
    /// so a wider pinch zooms more. Works in apps that don't take trackpad pinches.
    private func zoomInSteps(to distance: Double) {
        guard let start = pinchDistance else {
            pinchDistance = distance
            return
        }
        // About a tenth of the touchpad's width per step at the default sensitivity.
        let step = 200 / max(config.settings.pinchSensitivity, 0.1)
        if distance - start >= step {
            if let key = KeyCodes.byName["="] { synth.tap(key: key, modifiers: ["cmd"]) }
            pinchDistance = distance
        } else if start - distance >= step {
            if let key = KeyCodes.byName["-"] { synth.tap(key: key, modifiers: ["cmd"]) }
            pinchDistance = distance
        }
    }

    /// Moves the pointer by how far the finger slid since the last tick, like a trackpad.
    /// A new touch only sets where the finger is, so putting it down never makes the pointer jump.
    private func moveWithTouchpad(_ touch: DualSenseHID.Touch, dt: Double, precision: Double) {
        defer { lastTouch = touch }
        guard let last = lastTouch, last.id == touch.id else { return }
        let dx = Double(touch.x - last.x)
        let dy = Double(touch.y - last.y)
        guard dx != 0 || dy != 0 else { return }

        // The touchpad is 1920 units wide but only a few centimeters, so speed up fast swipes:
        // slow ones move about 0.35 pt per unit for precision, quick ones up to 2.3.
        let unitsPerSecond = hypot(dx, dy) / max(dt, 0.001)
        let gain = (0.35 + 0.65 * min(unitsPerSecond / 1500, 3)) * config.settings.touchpadSpeed * precision
        // The touchpad's y grows downward, like the screen's.
        synth.movePointer(dx: dx * gain, dy: dy * gain)
    }

    /// Applies the radial deadzone and response curve. Returns nil inside the deadzone.
    private func shaped(_ stick: CGPoint, curve: Double) -> CGPoint? {
        let magnitude = min(1, hypot(stick.x, stick.y))
        let deadzone = config.settings.deadzone
        guard magnitude > deadzone else { return nil }
        let scaled = pow((magnitude - deadzone) / (1 - deadzone), curve)
        return CGPoint(x: stick.x / magnitude * scaled, y: stick.y / magnitude * scaled)
    }

    private func press(_ button: PadButton, now: CFTimeInterval) {
        let action = config.activeTheme.action(for: button)
        guard enabled || action.type == .toggleEnabled else { return }
        switch action.type {
        case .none:
            return
        case .toggleEnabled:
            enabled.toggle()
            return
        case .nextTheme:
            onNextTheme?()
            return
        case .missionControl:
            SystemActions.showMissionControl()
            return
        case .appWindows:
            SystemActions.showAppWindows(using: synth)
            return
        case .leftClick: synth.mouseButton(.left, down: true)
        case .rightClick: synth.mouseButton(.right, down: true)
        case .middleClick: synth.mouseButton(.center, down: true)
        case .shortcut:
            perform(action)
            if action.repeat == true { nextRepeat[button] = now + repeatDelay }
        case .holdKey:
            synth.hold(key: action.key.flatMap { KeyCodes.byName[$0.lowercased()] }, modifiers: action.modifiers ?? [])
        case .precision:
            break
        }
        active[button] = action
    }

    private func release(_ button: PadButton) {
        nextRepeat[button] = nil
        guard let action = active.removeValue(forKey: button) else { return }
        switch action.type {
        case .leftClick: synth.mouseButton(.left, down: false)
        case .rightClick: synth.mouseButton(.right, down: false)
        case .middleClick: synth.mouseButton(.center, down: false)
        case .holdKey:
            synth.releaseHold(key: action.key.flatMap { KeyCodes.byName[$0.lowercased()] }, modifiers: action.modifiers ?? [])
        case .shortcut, .precision, .toggleEnabled, .nextTheme, .missionControl, .appWindows, .none:
            break
        }
    }

    private func reportPressed() {
        guard pressed != reportedPressed else { return }
        reportedPressed = pressed
        onPressedChange?(pressed)
    }

    /// Taps a shortcut action's key.
    private func perform(_ action: Action) {
        guard action.type == .shortcut, let name = action.key else { return }
        guard let code = KeyCodes.byName[name.lowercased()] else {
            NSLog("GamepadMouse: unknown key '\(name)'")
            return
        }
        synth.tap(key: code, modifiers: action.modifiers ?? [])
    }

    /// Lets go of every held mouse button and key, so nothing stays stuck down.
    private func releaseAll() {
        for button in Array(active.keys) { release(button) }
        synth.releaseAllMouseButtons()
        nextRepeat.removeAll()
        // Buttons still physically held stay in `pressed`, so they don't fire again
        // until they're let go and pressed anew.
    }
}
