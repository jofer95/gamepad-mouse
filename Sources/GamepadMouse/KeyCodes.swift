import CoreGraphics

/// Virtual key codes (ANSI layout) by the names the config file uses.
enum KeyCodes {
    static let byName: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "return": 36, "enter": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
        ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50,
        "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        "home": 115, "pageup": 116, "forwarddelete": 117, "end": 119, "pagedown": 121,
        "left": 123, "right": 124, "down": 125, "up": 126,
    ]

    /// Modifier keys: their key code and the flag they set while held.
    static let modifiers: [String: (code: CGKeyCode, flag: CGEventFlags)] = [
        "cmd": (55, .maskCommand), "command": (55, .maskCommand),
        "shift": (56, .maskShift),
        "option": (58, .maskAlternate), "alt": (58, .maskAlternate),
        "ctrl": (59, .maskControl), "control": (59, .maskControl),
        "fn": (63, .maskSecondaryFn),
    ]

    /// Modifier names in the order macOS shows them (⌃⌥⇧⌘).
    static let modifierOrder = ["ctrl", "option", "shift", "cmd", "fn"]

    private static let aliases: Set<String> = ["enter", "backspace", "esc", "command", "alt", "control"]

    /// Key code → the name the config uses for it.
    static let nameByCode: [CGKeyCode: String] = {
        var names: [CGKeyCode: String] = [:]
        for (name, code) in byName where !aliases.contains(name) { names[code] = name }
        return names
    }()

    static func name(for code: CGKeyCode) -> String? { nameByCode[code] }

    /// The same modifiers, spelled the canonical way and in macOS order.
    static func normalized(_ modifiers: [String]) -> [String] {
        let canonical: [String: String] = ["command": "cmd", "alt": "option", "control": "ctrl"]
        let names = Set(modifiers.map { canonical[$0.lowercased()] ?? $0.lowercased() })
        return modifierOrder.filter(names.contains)
    }

    /// A shortcut as macOS writes it, like "⌘W" or "⇧⌃".
    static func display(key: String?, modifiers: [String]) -> String {
        let symbols: [String: String] = ["ctrl": "⌃", "option": "⌥", "shift": "⇧", "cmd": "⌘", "fn": "fn "]
        let mods = normalized(modifiers).compactMap { symbols[$0] }.joined()
        guard let key = key?.lowercased() else { return mods.trimmingCharacters(in: .whitespaces) }
        let keySymbols: [String: String] = [
            "return": "↩", "enter": "↩", "tab": "⇥", "space": "Espacio", "delete": "⌫", "backspace": "⌫",
            "forwarddelete": "⌦", "escape": "⎋", "esc": "⎋", "up": "↑", "down": "↓", "left": "←", "right": "→",
            "home": "↖", "end": "↘", "pageup": "⇞", "pagedown": "⇟",
        ]
        return mods + (keySymbols[key] ?? key.uppercased())
    }
}
