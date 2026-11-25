import Foundation

/// Controller buttons, named after the DualSense (PS5). Face buttons are by position, so
/// `cross` is the bottom one on any controller (B on a Switch Pro, A on Xbox).
enum PadButton: String, Codable, CaseIterable {
    case cross, circle, square, triangle
    case l1, r1, l2, r2, l3, r3
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case options, create, ps, touchpad

    var title: String {
        switch self {
        case .cross: return "✕  " + tr("Cross", "Cruz")
        case .circle: return "○  " + tr("Circle", "Círculo")
        case .square: return "□  " + tr("Square", "Cuadrado")
        case .triangle: return "△  " + tr("Triangle", "Triángulo")
        case .l1: return "L1"
        case .r1: return "R1"
        case .l2: return "L2"
        case .r2: return "R2"
        case .l3: return "L3"
        case .r3: return "R3"
        case .dpadUp: return "↑  " + tr("Up", "Arriba")
        case .dpadDown: return "↓  " + tr("Down", "Abajo")
        case .dpadLeft: return "←  " + tr("Left", "Izquierda")
        case .dpadRight: return "→  " + tr("Right", "Derecha")
        case .options: return "Options"
        case .create: return "Create"
        case .ps: return tr("PS button", "Botón PS")
        case .touchpad: return "Touchpad"
        }
    }

    var detail: String? {
        switch self {
        case .l1, .r1: return "Bumper"
        case .l2, .r2: return tr("Trigger", "Gatillo")
        case .l3: return tr("Left stick click", "Clic del stick izquierdo")
        case .r3: return tr("Right stick click", "Clic del stick derecho")
        case .options: return tr("Right of the touchpad (≡)", "Derecha del touchpad (≡)")
        case .create: return tr("Left of the touchpad", "Izquierda del touchpad")
        case .touchpad: return tr("Click in the middle of the touchpad", "Clic en el centro del touchpad")
        case .ps: return tr("PlayStation logo", "Logo de PlayStation")
        default: return nil
        }
    }

    /// Buttons grouped as they sit on the controller, for the settings window.
    static var groups: [(title: String, buttons: [PadButton])] {
        [
            (tr("Face buttons", "Botones frontales"), [.cross, .circle, .square, .triangle]),
            (tr("Center", "Centro"), [.create, .touchpad, .options, .ps]),
            (tr("Bumpers and triggers", "Bumpers y gatillos"), [.l1, .r1, .l2, .r2]),
            ("D-pad", [.dpadUp, .dpadDown, .dpadLeft, .dpadRight]),
            ("Sticks", [.l3, .r3]),
        ]
    }
}

enum ActionType: String, Codable, CaseIterable, Identifiable {
    case none
    /// Mouse buttons: held while the controller button is held, so holding drags.
    case leftClick, rightClick, middleClick
    /// Taps `key` with `modifiers`. With `repeat: true` it repeats while held, like a keyboard.
    case shortcut
    /// Holds `key` and/or `modifiers` down while the button is held (push-to-talk).
    case holdKey
    /// Slows the pointer and scroll down while held, for small targets.
    case precision
    /// Shows every open window, to pick one with the pointer.
    case missionControl
    /// Shows the windows of the frontmost app.
    case appWindows
    /// Turns the mapping on and off (it stays listening for this button).
    case toggleEnabled
    /// Switches to the next theme in the list.
    case nextTheme

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return tr("No action", "Sin acción")
        case .leftClick: return tr("Left click", "Clic izquierdo")
        case .rightClick: return tr("Right click", "Clic derecho")
        case .middleClick: return tr("Middle click", "Clic central")
        case .shortcut: return tr("Keyboard shortcut", "Atajo de teclado")
        case .holdKey: return tr("Hold keys (dictation)", "Mantener teclas (dictado)")
        case .precision: return tr("Precision mode", "Modo precisión")
        case .missionControl: return "Mission Control"
        case .appWindows: return tr("App windows", "Ventanas de la app")
        case .toggleEnabled: return tr("Pause / resume", "Pausar / reanudar")
        case .nextTheme: return tr("Next theme", "Siguiente tema")
        }
    }
}

struct Action: Codable, Equatable {
    var type: ActionType
    var key: String?
    var modifiers: [String]?
    var `repeat`: Bool?

    static func shortcut(_ key: String, _ modifiers: [String] = [], repeat: Bool? = nil) -> Action {
        Action(type: .shortcut, key: key, modifiers: modifiers.isEmpty ? nil : modifiers, repeat: `repeat`)
    }

    static func of(_ type: ActionType) -> Action { Action(type: type) }

    /// Wispr Flow push-to-talk on this Mac: hold Shift + Control.
    static let dictate = Action(type: .holdKey, modifiers: ["shift", "ctrl"])
}

/// What sliding a finger on the DualSense touchpad does.
enum TouchpadMode: String, Codable, CaseIterable, Identifiable {
    case none
    /// Moves the pointer, like a laptop trackpad.
    case pointer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return tr("Nothing", "No hace nada")
        case .pointer: return tr("Moves the pointer", "Mueve el puntero")
        }
    }
}

/// A named set of button mappings. Pointer and scroll settings are shared by all themes.
struct Theme: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var buttons: [String: Action]
    /// Missing in themes saved before the touchpad could move the pointer.
    var touchpad: TouchpadMode? = nil

    func action(for button: PadButton) -> Action {
        buttons[button.rawValue] ?? .of(.none)
    }

    var touchpadMode: TouchpadMode { touchpad ?? .none }

    var isBuiltIn: Bool { Theme.builtInIDs.contains(id) }

    /// A built-in theme keeps its name in the Mac's language until it's renamed.
    var displayName: String {
        if let names = Theme.builtInNames[id], name == names.english || name == names.spanish {
            return tr(names.english, names.spanish)
        }
        return name.isEmpty ? tr("Untitled", "Sin nombre") : name
    }

    private static let builtInNames: [String: (english: String, spanish: String)] = [
        "classic": ("A · Classic", "A · Clásico"),
        "b": ("B · Clicks on buttons", "B · Clics en botones"),
        "c": ("C · Touchpad as mouse", "C · Touchpad como mouse"),
    ]
    private static let builtInIDs: Set<String> = ["classic", "b", "c"]

    private static func builtInName(_ id: String) -> String {
        let names = builtInNames[id]!
        return tr(names.english, names.spanish)
    }

    static var classic: Theme {
        Theme(id: "classic", name: builtInName("classic"), buttons: [
            PadButton.r2.rawValue: .of(.leftClick),
            PadButton.l2.rawValue: .of(.rightClick),
            PadButton.l1.rawValue: .shortcut("[", ["cmd"]),          // Back
            PadButton.r1.rawValue: .shortcut("]", ["cmd"]),          // Forward
            PadButton.circle.rawValue: .shortcut("w", ["cmd"]),      // Close window/tab
            PadButton.cross.rawValue: .dictate,
            PadButton.triangle.rawValue: .shortcut("return"),
            PadButton.square.rawValue: .of(.precision),
            PadButton.dpadUp.rawValue: .shortcut("up", repeat: true),
            PadButton.dpadDown.rawValue: .shortcut("down", repeat: true),
            PadButton.dpadLeft.rawValue: .shortcut("left", repeat: true),
            PadButton.dpadRight.rawValue: .shortcut("right", repeat: true),
            PadButton.create.rawValue: .shortcut("escape"),
            PadButton.options.rawValue: .shortcut("tab", ["cmd"]),   // Switch to the last app
            PadButton.touchpad.rawValue: .of(.leftClick),
            PadButton.r3.rawValue: .of(.middleClick),
            PadButton.l3.rawValue: .of(.none),
            PadButton.ps.rawValue: .of(.toggleEnabled),
        ])
    }

    /// Clicks on the face buttons, dictation on the touchpad, triggers free.
    static var faceClicks: Theme {
        Theme(id: "b", name: builtInName("b"), buttons: faceClickButtons)
    }

    /// Theme B's buttons, plus the touchpad moving the pointer.
    static var touchpadMouse: Theme {
        Theme(id: "c", name: builtInName("c"), buttons: faceClickButtons, touchpad: .pointer)
    }

    private static let faceClickButtons: [String: Action] = [
        PadButton.cross.rawValue: .of(.leftClick),
        PadButton.circle.rawValue: .of(.leftClick),
        PadButton.square.rawValue: .of(.rightClick),
        PadButton.triangle.rawValue: .of(.rightClick),
        PadButton.touchpad.rawValue: .dictate,
        PadButton.options.rawValue: .shortcut("return"),
        PadButton.create.rawValue: .shortcut("w", ["cmd"]),      // Close window/tab
        PadButton.l2.rawValue: .of(.none),
        PadButton.r2.rawValue: .of(.none),
        PadButton.l1.rawValue: .shortcut("[", ["cmd"]),
        PadButton.r1.rawValue: .shortcut("]", ["cmd"]),
        PadButton.dpadUp.rawValue: .of(.missionControl),
        PadButton.dpadDown.rawValue: .of(.appWindows),
        PadButton.dpadLeft.rawValue: .shortcut("left", repeat: true),
        PadButton.dpadRight.rawValue: .shortcut("right", repeat: true),
        PadButton.r3.rawValue: .of(.middleClick),
        PadButton.l3.rawValue: .of(.none),
        PadButton.ps.rawValue: .of(.toggleEnabled),
    ]

    static var builtIns: [Theme] { [classic, faceClicks, touchpadMouse] }
}

struct Settings: Codable, Equatable {
    /// Pointer speed at full stick tilt, in points per second.
    var pointerMaxSpeed = 1600.0
    /// Higher = finer control near the center of the stick, same top speed.
    var pointerCurve = 2.2
    /// Scroll speed at full stick tilt, in pixels per second.
    var scrollMaxSpeed = 2200.0
    var scrollCurve = 2.0
    var invertScrollVertical = false
    var invertScrollHorizontal = false
    /// Multiplier applied to pointer and scroll speed while a `precision` button is held.
    var precisionFactor = 0.3
    /// Stick tilt (0–1) ignored around the center, so a resting stick doesn't drift.
    var deadzone = 0.12
    /// `left` or `right`: which stick moves the pointer. The other one scrolls.
    var pointerStick = "left"
    /// Multiplier for the touchpad pointer. Fast swipes are accelerated on top of it.
    var touchpadSpeed = 1.0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        pointerMaxSpeed = try c.decodeIfPresent(Double.self, forKey: .pointerMaxSpeed) ?? d.pointerMaxSpeed
        pointerCurve = try c.decodeIfPresent(Double.self, forKey: .pointerCurve) ?? d.pointerCurve
        scrollMaxSpeed = try c.decodeIfPresent(Double.self, forKey: .scrollMaxSpeed) ?? d.scrollMaxSpeed
        scrollCurve = try c.decodeIfPresent(Double.self, forKey: .scrollCurve) ?? d.scrollCurve
        invertScrollVertical = try c.decodeIfPresent(Bool.self, forKey: .invertScrollVertical) ?? d.invertScrollVertical
        invertScrollHorizontal = try c.decodeIfPresent(Bool.self, forKey: .invertScrollHorizontal) ?? d.invertScrollHorizontal
        precisionFactor = try c.decodeIfPresent(Double.self, forKey: .precisionFactor) ?? d.precisionFactor
        deadzone = try c.decodeIfPresent(Double.self, forKey: .deadzone) ?? d.deadzone
        pointerStick = try c.decodeIfPresent(String.self, forKey: .pointerStick) ?? d.pointerStick
        touchpadSpeed = try c.decodeIfPresent(Double.self, forKey: .touchpadSpeed) ?? d.touchpadSpeed
    }
}

struct Config: Codable, Equatable {
    var settings = Settings()
    var activeThemeID = "classic"
    var themes = Theme.builtIns

    var activeTheme: Theme {
        themes.first { $0.id == activeThemeID } ?? themes.first ?? Theme.classic
    }

    init() {}

    private enum CodingKeys: String, CodingKey { case settings, activeThemeID, themes }
    /// The first version kept a single `buttons` map and no themes.
    private enum LegacyKeys: String, CodingKey { case buttons }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()

        if let saved = try c.decodeIfPresent([Theme].self, forKey: .themes), !saved.isEmpty {
            // Built-in themes can't be deleted, and new ones arrive with updates, so add any missing.
            themes = saved + Theme.builtIns.filter { builtIn in !saved.contains { $0.id == builtIn.id } }
            let active = try c.decodeIfPresent(String.self, forKey: .activeThemeID)
            activeThemeID = themes.contains { $0.id == active } ? active! : themes[0].id
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let old = try legacy.decodeIfPresent([String: Action].self, forKey: .buttons) ?? [:]
            let merged = Theme.classic.buttons.merging(old) { _, new in new }
            themes = Theme.builtIns
            if merged != Theme.classic.buttons {
                themes.append(Theme(id: UUID().uuidString, name: tr("My setup", "Mi configuración"), buttons: merged))
            }
            activeThemeID = "b"
        }

        for theme in themes {
            for name in theme.buttons.keys where PadButton(rawValue: name) == nil {
                NSLog("GamepadMouse: unknown button '\(name)' in theme '\(theme.name)', ignored")
            }
        }
    }

    // MARK: File

    static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("GamepadMouse/config.json")
    }

    /// Reads the config file, or returns the defaults if there is none.
    static func load() -> Result<Config, Error> {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .success(Config()) }
        do {
            return .success(try JSONDecoder().decode(Config.self, from: Data(contentsOf: fileURL)))
        } catch {
            return .failure(error)
        }
    }

    func save() throws {
        let url = Config.fileURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
