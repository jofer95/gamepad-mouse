import AppKit
import ApplicationServices
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controllers = ControllerManager()
    private var store: ConfigStore!
    private var engine: Engine!
    private var statusItem: NSStatusItem!
    private var statusTimer: Timer?
    private var settingsWindow: NSWindow?

    private let controllerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let enabledItem = NSMenuItem(title: tr("Enabled", "Activado"), action: #selector(toggleEnabled), keyEquivalent: "e")
    private let lockItem = NSMenuItem(title: "", action: #selector(toggleLock), keyEquivalent: "l")
    private let themesItem = NSMenuItem(title: tr("Theme", "Tema"), action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: tr("Open at Login", "Abrir al iniciar sesión"), action: #selector(toggleLoginItem), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config: Config
        switch Config.load() {
        case .success(let loaded): config = loaded
        case .failure(let error):
            config = Config()
            showConfigError(error)
        }

        store = ConfigStore(config: config)
        // Writes the file on first run, and in the current format after an upgrade.
        store.saveNow()

        engine = Engine(controllers: controllers, config: config)
        store.onChange = { [weak self] config in
            self?.engine.config = config
            self?.refreshStatus()
        }
        engine.onEnabledChange = { [weak self] in self?.refreshStatus() }
        engine.onLockChange = { [weak self] in self?.refreshStatus() }
        engine.onPressedChange = { [weak self] pressed in self?.store.setPressed(pressed) }
        engine.onNextTheme = { [weak self] in self?.store.selectNextTheme() }
        controllers.onChange = { [weak self] in
            self?.engine.updateLight()
            self?.refreshStatus()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.menu = buildMenu()

        promptForAccessibilityIfNeeded()
        engine.start()
        refreshStatus()

        // The Accessibility grant happens in System Settings, so check for it now and then.
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refreshStatus() }
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer

        // `open GamepadMouse.app --args --settings` opens straight to the mapping window.
        if CommandLine.arguments.contains("--settings") { openSettings() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    // MARK: Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        controllerItem.isEnabled = false
        menu.addItem(controllerItem)
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        lockItem.target = self
        menu.addItem(lockItem)
        enabledItem.target = self
        menu.addItem(enabledItem)
        themesItem.submenu = NSMenu()
        menu.addItem(themesItem)
        menu.addItem(item(tr("Configure Buttons…", "Configurar botones…"), #selector(openSettings), ","))
        menu.addItem(.separator())
        menu.addItem(item(tr("Edit JSON File…", "Editar archivo JSON…"), #selector(openConfigFile), ""))
        menu.addItem(item(tr("Reload JSON File", "Recargar archivo JSON"), #selector(reloadConfig), "r"))
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(item(tr("Quit Gamepad Mouse", "Salir de Gamepad Mouse"), #selector(quit), "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuWillOpen(_ menu: NSMenu) { refreshStatus() }

    private func rebuildThemesMenu() {
        guard let submenu = themesItem.submenu else { return }
        submenu.removeAllItems()
        for theme in store.config.themes {
            let item = NSMenuItem(title: theme.displayName,
                                  action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.id
            item.state = theme.id == store.config.activeThemeID ? .on : .off
            submenu.addItem(item)
        }
        themesItem.title = tr("Theme", "Tema") + ": \(store.activeTheme.displayName)"
    }

    private func refreshStatus() {
        let trusted = AXIsProcessTrusted()
        let connected = controllers.controller != nil

        if let name = controllers.name {
            let battery = controllers.batteryDescription.map { " · \($0)" } ?? ""
            controllerItem.title = "\(name)\(battery)"
        } else {
            controllerItem.title = tr("No controller connected", "No hay control conectado")
        }
        accessibilityItem.title = trusted
            ? tr("Accessibility: allowed", "Accesibilidad: permitida")
            : "⚠️ " + tr("Allow Accessibility Access…", "Permitir acceso de Accesibilidad…")
        accessibilityItem.isEnabled = !trusted
        enabledItem.state = engine.enabled ? .on : .off
        lockItem.title = engine.locked
            ? "🔒 " + tr("Locked: press mute to unlock", "Bloqueado: presiona mute para desbloquear")
            : tr("Lock Controller", "Bloquear el control")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        rebuildThemesMenu()

        let symbol: String
        if !trusted {
            symbol = "exclamationmark.triangle"
        } else if !connected {
            symbol = "gamecontroller"
        } else if engine.locked {
            symbol = "lock.fill"
        } else {
            symbol = engine.enabled ? "gamecontroller.fill" : "pause.circle"
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Gamepad Mouse")
    }

    // MARK: Actions

    @objc private func toggleEnabled() { engine.enabled.toggle() }

    @objc private func toggleLock() { engine.locked.toggle() }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { store.selectTheme(id) }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store)))
            window.title = "Gamepad Mouse"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 900, height: 680))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openConfigFile() {
        store.saveNow()
        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        NSWorkspace.shared.open([Config.fileURL], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func reloadConfig() {
        switch Config.load() {
        case .success(let config): store.config = config
        case .failure(let error): showConfigError(error)
        }
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert(tr("Couldn't change Open at Login", "No se pudo cambiar Abrir al iniciar sesión"), error.localizedDescription)
        }
        refreshStatus()
    }

    @objc private func openAccessibilitySettings() {
        promptForAccessibilityIfNeeded()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Helpers

    private func promptForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func showConfigError(_ error: Error) {
        showAlert(tr("Couldn't read the config", "No se pudo leer la configuración"),
                  "\(Config.fileURL.path)\n\n\(error)\n\n" + tr("The previous settings are still in use.", "Se sigue usando la configuración anterior."))
    }

    private func showAlert(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
