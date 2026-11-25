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
            Text("Temas")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 4)
            Text("El tema seleccionado es el que usa el control.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            List(selection: selection) {
                ForEach(store.config.themes) { theme in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(theme.name.isEmpty ? "Sin nombre" : theme.name)
                        if theme.isBuiltIn {
                            Text("Predeterminado").font(.caption2).foregroundStyle(.secondary)
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
                .help("Crear un tema nuevo como copia del seleccionado")
                Button { store.deleteActiveTheme() } label: {
                    Image(systemName: "minus").frame(width: 22, height: 22)
                }
                .disabled(store.activeTheme.isBuiltIn)
                .help(store.activeTheme.isBuiltIn
                      ? "Los temas predeterminados no se pueden borrar"
                      : "Borrar el tema seleccionado")
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
                TextField("Nombre del tema", text: Binding(
                    get: { store.activeTheme.name },
                    set: { store.renameActiveTheme($0) }))
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .frame(maxWidth: 300)
                Spacer()
                if store.activeTheme.isBuiltIn {
                    Button("Restaurar original") { store.restoreActiveTheme() }
                        .help("Regresa este tema a como venía")
                }
            }
            .padding([.horizontal, .top], 18)
            .padding(.bottom, 10)

            Picker("", selection: $tab) {
                Text("Botones").tag(Tab.buttons)
                Text("Movimiento").tag(Tab.movement)
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
                Label("Presiona un botón del control y su fila se ilumina aquí.", systemImage: "gamecontroller")
                    .foregroundStyle(.secondary)
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
                    Toggle("Repetir", isOn: Binding(
                        get: { action.repeat == true },
                        set: { action.repeat = $0 ? true : nil }))
                        .toggleStyle(.checkbox)
                        .help("Repetir el atajo mientras mantienes el botón, como una tecla")
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
                Label("Estos ajustes aplican a todos los temas.", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
            Section("Puntero") {
                Picker("Stick del puntero", selection: setting(\.pointerStick)) {
                    Text("Izquierdo (el derecho hace scroll)").tag("left")
                    Text("Derecho (el izquierdo hace scroll)").tag("right")
                }
                SliderRow(title: "Velocidad máxima", value: setting(\.pointerMaxSpeed),
                          range: 300...4000, step: 100) { "\(Int($0)) pt/s" }
                SliderRow(title: "Control fino al inicio", value: setting(\.pointerCurve),
                          range: 1...4, step: 0.1) { String(format: "%.1f", $0) }
            }
            Section("Scroll") {
                SliderRow(title: "Velocidad máxima", value: setting(\.scrollMaxSpeed),
                          range: 300...6000, step: 100) { "\(Int($0)) px/s" }
                SliderRow(title: "Control fino al inicio", value: setting(\.scrollCurve),
                          range: 1...4, step: 0.1) { String(format: "%.1f", $0) }
                Toggle("Invertir scroll vertical", isOn: setting(\.invertScrollVertical))
                Toggle("Invertir scroll horizontal", isOn: setting(\.invertScrollHorizontal))
            }
            Section("General") {
                SliderRow(title: "Velocidad en modo precisión", value: setting(\.precisionFactor),
                          range: 0.1...1, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
                SliderRow(title: "Zona muerta de los sticks", value: setting(\.deadzone),
                          range: 0.02...0.4, step: 0.01) { "\(Int(($0 * 100).rounded()))%" }
            }
            Section {
                HStack {
                    Spacer()
                    Button("Restaurar ajustes de movimiento") {
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
