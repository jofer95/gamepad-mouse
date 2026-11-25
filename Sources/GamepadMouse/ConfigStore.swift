import Foundation

/// The live config shared by the engine, the menu and the settings window.
/// Every change applies right away and is saved to disk shortly after.
final class ConfigStore: ObservableObject {
    @Published var config: Config {
        didSet {
            guard config != oldValue else { return }
            onChange?(config)
            scheduleSave()
        }
    }

    /// Controller buttons held right now, so the settings window can highlight them.
    @Published private(set) var pressed: Set<PadButton> = []

    var onChange: ((Config) -> Void)?
    private var pendingSave: DispatchWorkItem?

    init(config: Config) {
        self.config = config
    }

    var activeTheme: Theme { config.activeTheme }

    func setPressed(_ buttons: Set<PadButton>) {
        if buttons != pressed { pressed = buttons }
    }

    // MARK: Themes

    func selectTheme(_ id: String) {
        guard config.themes.contains(where: { $0.id == id }) else { return }
        config.activeThemeID = id
    }

    func selectNextTheme() {
        let themes = config.themes
        guard let index = themes.firstIndex(where: { $0.id == config.activeThemeID }) else { return }
        config.activeThemeID = themes[(index + 1) % themes.count].id
    }

    func duplicateActiveTheme() {
        var copy = activeTheme
        copy.id = UUID().uuidString
        copy.name = "Copia de \(activeTheme.name)"
        var updated = config
        updated.themes.append(copy)
        updated.activeThemeID = copy.id
        config = updated
    }

    /// Deletes the active theme unless it's built in, and selects the first theme.
    func deleteActiveTheme() {
        guard !activeTheme.isBuiltIn else { return }
        var updated = config
        updated.themes.removeAll { $0.id == config.activeThemeID }
        updated.activeThemeID = updated.themes[0].id
        config = updated
    }

    /// Puts a built-in theme back the way it ships.
    func restoreActiveTheme() {
        guard let original = Theme.builtIns.first(where: { $0.id == config.activeThemeID }) else { return }
        updateActiveTheme { $0 = original }
    }

    func renameActiveTheme(_ name: String) {
        updateActiveTheme { $0.name = name }
    }

    func action(for button: PadButton) -> Action {
        activeTheme.action(for: button)
    }

    func setAction(_ action: Action, for button: PadButton) {
        updateActiveTheme { $0.buttons[button.rawValue] = action }
    }

    private func updateActiveTheme(_ change: (inout Theme) -> Void) {
        guard let index = config.themes.firstIndex(where: { $0.id == config.activeThemeID }) else { return }
        change(&config.themes[index])
    }

    // MARK: Disk

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        do { try config.save() } catch { NSLog("GamepadMouse: couldn't save config: \(error)") }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let save = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = save
        // Sliders change the config many times a second; write once they settle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: save)
    }
}
