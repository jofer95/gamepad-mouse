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

        guard enabled else { return }
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
