import AppKit
import CoreGraphics

/// Posts synthetic mouse, scroll and keyboard events to the system.
/// Needs the Accessibility permission; without it macOS drops the events silently.
final class InputSynthesizer {
    private let source: CGEventSource? = {
        let source = CGEventSource(stateID: .hidSystemState)
        // Keep the real mouse and keyboard usable right after a synthetic event.
        source?.localEventsSuppressionInterval = 0
        return source
    }()

    private var buttonsDown: Set<UInt32> = []
    private var pointerRemainder = CGPoint.zero
    private var scrollRemainder = CGPoint.zero
    private var lastClick: (button: CGMouseButton, time: TimeInterval, location: CGPoint, count: Int64)?
    private var currentClickCount: [UInt32: Int64] = [:]

    // MARK: Pointer

    func movePointer(dx: Double, dy: Double) {
        pointerRemainder.x += dx
        pointerRemainder.y += dy
        let stepX = pointerRemainder.x.rounded(.towardZero)
        let stepY = pointerRemainder.y.rounded(.towardZero)
        guard stepX != 0 || stepY != 0 else { return }
        pointerRemainder.x -= stepX
        pointerRemainder.y -= stepY

        let current = currentLocation
        let location = clampToScreens(CGPoint(x: current.x + stepX, y: current.y + stepY))
        let (type, button) = moveEventType()
        guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                  mouseCursorPosition: location, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(stepX))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(stepY))
        event.post(tap: .cghidEventTap)
    }

    func mouseButton(_ button: CGMouseButton, down: Bool) {
        let key = button.rawValue
        if down == buttonsDown.contains(key) { return }
        let location = currentLocation
        let type: CGEventType
        switch button {
        case .left: type = down ? .leftMouseDown : .leftMouseUp
        case .right: type = down ? .rightMouseDown : .rightMouseUp
        default: type = down ? .otherMouseDown : .otherMouseUp
        }

        let clickCount: Int64
        if down {
            clickCount = nextClickCount(button: button, at: location)
            currentClickCount[key] = clickCount
            buttonsDown.insert(key)
        } else {
            clickCount = currentClickCount[key] ?? 1
            buttonsDown.remove(key)
        }

        guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                  mouseCursorPosition: location, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: clickCount)
        if button != .left && button != .right {
            event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button.rawValue))
        }
        event.post(tap: .cghidEventTap)
    }

    func releaseAllMouseButtons() {
        for raw in buttonsDown {
            if let button = CGMouseButton(rawValue: raw) { mouseButton(button, down: false) }
        }
    }

    // MARK: Scroll

    /// `dx`/`dy` in pixels; positive `dy` scrolls up, positive `dx` scrolls right.
    func scroll(dx: Double, dy: Double) {
        scrollRemainder.x += dx
        scrollRemainder.y += dy
        let stepX = scrollRemainder.x.rounded(.towardZero)
        let stepY = scrollRemainder.y.rounded(.towardZero)
        guard stepX != 0 || stepY != 0 else { return }
        scrollRemainder.x -= stepX
        scrollRemainder.y -= stepY
        // wheel2 > 0 scrolls left, so flip it to make positive dx scroll right.
        guard let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                                  wheel1: Int32(stepY), wheel2: Int32(-stepX), wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }

    // MARK: Keyboard

    /// Presses and releases `key` with `modifiers` held, like typing a shortcut.
    func tap(key: CGKeyCode, modifiers: [String]) {
        let flags = pressModifiers(modifiers)
        postKey(key, down: true, flags: flags)
        postKey(key, down: false, flags: flags)
        releaseModifiers(modifiers)
    }

    /// Holds a key and/or modifiers down until `releaseHold` is called with the same values.
    func hold(key: CGKeyCode?, modifiers: [String]) {
        let flags = pressModifiers(modifiers)
        if let key { postKey(key, down: true, flags: flags) }
    }

    func releaseHold(key: CGKeyCode?, modifiers: [String]) {
        if let key { postKey(key, down: false, flags: flags(for: modifiers)) }
        releaseModifiers(modifiers)
    }

    // MARK: Helpers

    var currentLocation: CGPoint { CGEvent(source: nil)?.location ?? .zero }

    private func moveEventType() -> (CGEventType, CGMouseButton) {
        if buttonsDown.contains(CGMouseButton.left.rawValue) { return (.leftMouseDragged, .left) }
        if buttonsDown.contains(CGMouseButton.right.rawValue) { return (.rightMouseDragged, .right) }
        if buttonsDown.contains(CGMouseButton.center.rawValue) { return (.otherMouseDragged, .center) }
        return (.mouseMoved, .left)
    }

    private func nextClickCount(button: CGMouseButton, at location: CGPoint) -> Int64 {
        let now = ProcessInfo.processInfo.systemUptime
        var count: Int64 = 1
        if let last = lastClick, last.button == button,
           now - last.time <= NSEvent.doubleClickInterval,
           hypot(last.location.x - location.x, last.location.y - location.y) < 5 {
            count = last.count + 1
        }
        lastClick = (button, now, location, count)
        return count
    }

    private func clampToScreens(_ point: CGPoint) -> CGPoint {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return point }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        // Keep the point on whichever display is closest to it.
        var best = point
        var bestDistance = Double.infinity
        for display in displays {
            let bounds = CGDisplayBounds(display)
            let clamped = CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX - 1),
                                  y: min(max(point.y, bounds.minY), bounds.maxY - 1))
            let distance = hypot(clamped.x - point.x, clamped.y - point.y)
            if distance < bestDistance { best = clamped; bestDistance = distance }
        }
        return best
    }

    private func flags(for modifiers: [String]) -> CGEventFlags {
        modifiers.reduce(into: CGEventFlags()) { flags, name in
            if let modifier = KeyCodes.modifiers[name.lowercased()] { flags.insert(modifier.flag) }
        }
    }

    /// Sends a key-down for each modifier, so apps that watch the modifier keys
    /// themselves (like Wispr Flow's push-to-talk) see them, not only the flags.
    @discardableResult
    private func pressModifiers(_ modifiers: [String]) -> CGEventFlags {
        var flags = CGEventFlags()
        for name in modifiers {
            guard let modifier = KeyCodes.modifiers[name.lowercased()] else { continue }
            flags.insert(modifier.flag)
            postModifier(modifier.code, down: true, flags: flags)
        }
        return flags
    }

    private func releaseModifiers(_ modifiers: [String]) {
        var flags = flags(for: modifiers)
        for name in modifiers.reversed() {
            guard let modifier = KeyCodes.modifiers[name.lowercased()] else { continue }
            flags.remove(modifier.flag)
            postModifier(modifier.code, down: false, flags: flags)
        }
    }

    private func postModifier(_ code: CGKeyCode, down: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return }
        event.type = .flagsChanged
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    private func postKey(_ code: CGKeyCode, down: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}
