import SwiftUI

/// The button-mapping window: themes on the left, the selected theme's buttons on the right.
/// Selecting a theme makes it the active one, and every edit applies right away.
struct SettingsView: View {
    @ObservedObject var store: ConfigStore

    var body: some View {
        HStack(spacing: 0) {
            ThemeList(store: store)
                .frame(width: 220)
            Divider()
            ThemeEditor(store: store)
        }
        .frame(minWidth: 860, minHeight: 620)
    }
}

// MARK: - Theme list

private struct ThemeList: View {
    @ObservedObject var store: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tr("Themes", "Temas"))
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 4)
            Text(tr("The selected theme is the one the controller uses.",
                    "El tema seleccionado es el que usa el control."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            List(selection: selection) {
                ForEach(store.config.themes) { theme in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(theme.displayName)
                        if theme.isBuiltIn {
                            Text(tr("Built-in", "Predeterminado")).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .tag(theme.id)
                }
            }
            .listStyle(.sidebar)

            Divider()
            HStack(spacing: 2) {
                Button { store.duplicateActiveTheme() } label: {
                    Image(systemName: "plus").frame(width: 22, height: 22)
                }
                .help(tr("Create a new theme as a copy of the selected one",
                         "Crear un tema nuevo como copia del seleccionado"))
                Button { store.deleteActiveTheme() } label: {
                    Image(systemName: "minus").frame(width: 22, height: 22)
                }
                .disabled(store.activeTheme.isBuiltIn)
                .help(store.activeTheme.isBuiltIn
                      ? tr("Built-in themes can't be deleted", "Los temas predeterminados no se pueden borrar")
                      : tr("Delete the selected theme", "Borrar el tema seleccionado"))
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(6)
        }
    }

    private var selection: Binding<String?> {
        Binding(get: { store.config.activeThemeID },
                set: { id in if let id { store.selectTheme(id) } })
    }
}

// MARK: - Theme editor

private struct ThemeEditor: View {
    @ObservedObject var store: ConfigStore
    @State private var tab = Tab.buttons

    enum Tab { case buttons, movement }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TextField(tr("Theme name", "Nombre del tema"), text: Binding(
                    get: { store.activeTheme.displayName },
                    set: { store.renameActiveTheme($0) }))
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .frame(maxWidth: 300)
                Spacer()
                if store.activeTheme.isBuiltIn {
                    Button(tr("Restore original", "Restaurar original")) { store.restoreActiveTheme() }
                        .help(tr("Put this theme back the way it shipped", "Regresa este tema a como venía"))
                }
            }
            .padding([.horizontal, .top], 18)
            .padding(.bottom, 10)

            Picker("", selection: $tab) {
                Text(tr("Buttons", "Botones")).tag(Tab.buttons)
                Text(tr("Movement", "Movimiento")).tag(Tab.movement)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 280)
            .padding(.bottom, 4)

            switch tab {
            case .buttons: ButtonsForm(store: store)
            case .movement: MovementForm(store: store)
            }
        }
    }
}

// MARK: - Buttons

private struct ButtonsForm: View {
    @ObservedObject var store: ConfigStore

    var body: some View {
        Form {
            Section {
                Label(tr("Press a button on the controller and its row lights up here.",
                         "Presiona un botón del control y su fila se ilumina aquí."),
                      systemImage: "gamecontroller")
                    .foregroundStyle(.secondary)
            }
            Section(tr("Touchpad", "Touchpad")) {
                Picker(tr("Sliding a finger", "Al deslizar el dedo"), selection: Binding(
                    get: { store.activeTheme.touchpadMode },
                    set: { store.setTouchpadMode($0) })) {
                    ForEach(TouchpadMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                if store.activeTheme.touchpadMode == .pointer {
                    SliderRow(title: tr("Touchpad speed", "Velocidad del touchpad"),
                              value: Binding(get: { store.config.settings.touchpadSpeed },
                                             set: { store.config.settings.touchpadSpeed = $0 }),
                              range: 0.3...3, step: 0.1) { String(format: "%.1f×", $0) }
                    SliderRow(title: tr("Pinch zoom sensitivity", "Sensibilidad del zoom"),
                              value: Binding(get: { store.config.settings.pinchSensitivity },
                                             set: { store.config.settings.pinchSensitivity = $0 }),
                              range: 0.5...2.5, step: 0.1) { String(format: "%.1f×", $0) }
                    SmoothZoomToggle(isOn: Binding(get: { store.config.settings.smoothZoom },
                                                   set: { store.config.settings.smoothZoom = $0 }))
                    Text(tr("One finger: slide slowly for precision, quickly to cross the screen. Two fingers: spread to zoom in, pinch to zoom out. Clicking the touchpad is its own button, below.",
                            "Un dedo: desliza lento para precisión y rápido para cruzar la pantalla. Dos dedos: sepáralos para acercar y júntalos para alejar. El clic del touchpad es un botón aparte, abajo."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(PadButton.groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.buttons, id: \.self) { button in
                        ButtonRow(button: button,
                                  action: binding(for: button),
                                  pressed: store.pressed.contains(button))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for button: PadButton) -> Binding<Action> {
        Binding(get: { store.action(for: button) },
                set: { store.setAction($0, for: button) })
    }
}

private struct ButtonRow: View {
    let button: PadButton
    @Binding var action: Action
    let pressed: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(button.title).fontWeight(.medium)
                if let detail = button.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)

            // Fixed-width columns keep the recorders and pickers lined up across rows.
            HStack(spacing: 10) {
                if action.type == .shortcut || action.type == .holdKey {
                    ShortcutRecorder(key: action.key,
                                     modifiers: action.modifiers ?? [],
                                     allowModifiersOnly: action.type == .holdKey) { key, modifiers in
                        action.key = key
                        action.modifiers = modifiers.isEmpty ? nil : modifiers
                    }
                }
                if action.type == .shortcut {
                    Toggle(tr("Repeat", "Repetir"), isOn: Binding(
                        get: { action.repeat == true },
                        set: { action.repeat = $0 ? true : nil }))
                        .toggleStyle(.checkbox)
                        .help(tr("Repeat the shortcut while you hold the button, like a key",
                                 "Repetir el atajo mientras mantienes el botón, como una tecla"))
                }
            }
            .frame(width: 250, alignment: .leading)

            Picker("", selection: typeBinding) {
                ForEach(ActionType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .labelsHidden()
            .frame(width: 220, alignment: .trailing)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(pressed ? Color.accentColor.opacity(0.25) : Color.clear)
        )
        .animation(.easeOut(duration: 0.12), value: pressed)
    }

    /// Changing the type keeps what still makes sense and fills in a useful start.
    private var typeBinding: Binding<ActionType> {
        Binding(get: { action.type }, set: { type in
            guard type != action.type else { return }
            switch type {
            case .shortcut:
                action = Action(type: .shortcut, key: action.key, modifiers: action.modifiers)
            case .holdKey:
                action = action.key == nil && (action.modifiers ?? []).isEmpty
                    ? .dictate
                    : Action(type: .holdKey, key: action.key, modifiers: action.modifiers)
            default:
                action = .of(type)
            }
        })
    }
}

// MARK: - Movement

private struct MovementForm: View {
    @ObservedObject var store: ConfigStore

    var body: some View {
        Form {
            Section {
                Label(tr("These settings apply to every theme.", "Estos ajustes aplican a todos los temas."),
                      systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
            Section(tr("Pointer", "Puntero")) {
                Picker(tr("Pointer stick", "Stick del puntero"), selection: setting(\.pointerStick)) {
                    Text(tr("Left (the right one scrolls)", "Izquierdo (el derecho hace scroll)")).tag("left")
                    Text(tr("Right (the left one scrolls)", "Derecho (el izquierdo hace scroll)")).tag("right")
                }
                SliderRow(title: tr("Top speed", "Velocidad máxima"), value: setting(\.pointerMaxSpeed),
                          range: 300...4000, step: 100) { "\(Int($0)) pt/s" }
                SliderRow(title: tr("Fine control near center", "Control fino al inicio"), value: setting(\.pointerCurve),
                          range: 1...4, step: 0.1) { String(format: "%.1f", $0) }
            }
            Section("Scroll") {
                SliderRow(title: tr("Top speed", "Velocidad máxima"), value: setting(\.scrollMaxSpeed),
                          range: 300...6000, step: 100) { "\(Int($0)) px/s" }
                SliderRow(title: tr("Fine control near center", "Control fino al inicio"), value: setting(\.scrollCurve),
                          range: 1...4, step: 0.1) { String(format: "%.1f", $0) }
                Toggle(tr("Invert vertical scroll", "Invertir scroll vertical"), isOn: setting(\.invertScrollVertical))
                Toggle(tr("Invert horizontal scroll", "Invertir scroll horizontal"), isOn: setting(\.invertScrollHorizontal))
            }
            Section("Touchpad") {
                SliderRow(title: tr("Touchpad speed", "Velocidad del touchpad"), value: setting(\.touchpadSpeed),
                          range: 0.3...3, step: 0.1) { String(format: "%.1f×", $0) }
                SliderRow(title: tr("Pinch zoom sensitivity", "Sensibilidad del zoom"), value: setting(\.pinchSensitivity),
                          range: 0.5...2.5, step: 0.1) { String(format: "%.1f×", $0) }
                SmoothZoomToggle(isOn: setting(\.smoothZoom))
            }
            Section(tr("General", "General")) {
                SliderRow(title: tr("Precision mode speed", "Velocidad en modo precisión"), value: setting(\.precisionFactor),
                          range: 0.1...1, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
                SliderRow(title: tr("Stick dead zone", "Zona muerta de los sticks"), value: setting(\.deadzone),
                          range: 0.02...0.4, step: 0.01) { "\(Int(($0 * 100).rounded()))%" }
            }
            Section {
                HStack {
                    Spacer()
                    Button(tr("Restore movement settings", "Restaurar ajustes de movimiento")) {
                        store.config.settings = Settings()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<Settings, Value>) -> Binding<Value> {
        Binding(get: { store.config.settings[keyPath: keyPath] },
                set: { store.config.settings[keyPath: keyPath] = $0 })
    }
}

private struct SmoothZoomToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(tr("Smooth zoom, like the Mac trackpad", "Zoom suave, como el trackpad de la Mac"), isOn: $isOn)
            Text(isOn
                 ? tr("Works in apps that take trackpad pinches: Safari, Chrome, Preview, Maps, Photos. Turn it off for Terminal or VS Code.",
                      "Funciona en apps que aceptan el pellizco del trackpad: Safari, Chrome, Vista Previa, Mapas, Fotos. Apágalo para la Terminal o VS Code.")
                 : tr("Zooms in steps with ⌘= and ⌘-, which works in almost every app.",
                      "Hace zoom por pasos con ⌘= y ⌘-, que funciona en casi todas las apps."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range, step: step)
                .frame(minWidth: 220)
            Text(format(value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
    }
}
