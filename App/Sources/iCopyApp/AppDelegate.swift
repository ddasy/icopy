import AppKit
import Carbon
import ClipboardPanel

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let appearance = ClipboardAppearancePreferences()
    private lazy var shortcutSettings = ShortcutSettingsModel(preference: shortcutPreference)
    private lazy var panelController = ClipboardPanelWindowController(
        appearance: appearance,
        openSettings: { [weak self] in self?.showSettingsWindow() }
    )
    private lazy var settingsController = SettingsWindowController(
        appearance: appearance,
        shortcutSettings: shortcutSettings
    )
    private let hotKeyRegistrar = GlobalHotKeyRegistrar()
    private let doubleCommandMonitor = DoubleCommandMonitor()
    private var shortcutPreference = ShortcutPreference.load()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        shortcutSettings.customize = { [weak self] in self?.promptCustomShortcut() }
        shortcutSettings.useDefault = { [weak self] in self?.useDefaultShortcut() }
        configureStatusItem()
        applyShortcutPreference()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "iCopy")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "iCopy 剪切板"
        item.menu = makeStatusMenu()
        statusItem = item
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let showItem = NSMenuItem(title: "显示剪切板", action: #selector(showClipboardPanel), keyEquivalent: "")
        showItem.target = self
        showItem.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: nil)
        menu.addItem(showItem)

        let settingsItem = NSMenuItem(title: "打开设置…", action: #selector(showSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 iCopy", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)

        return menu
    }

    private func applyShortcutPreference() {
        hotKeyRegistrar.unregister()
        doubleCommandMonitor.stop()

        switch shortcutPreference {
        case .doubleCommand:
            doubleCommandMonitor.start { [weak self] in
                self?.panelController.showOrToggle()
            }
        case .hotKey(let shortcut):
            hotKeyRegistrar.register(shortcut: shortcut) { [weak self] in
                Task { @MainActor in
                    self?.panelController.showOrToggle()
                }
            }
        }
    }

    private func refreshShortcutMenu() {
        shortcutSettings.refresh(preference: shortcutPreference)
    }

    @objc
    private func showClipboardPanel() {
        panelController.show()
    }

    @objc
    private func showSettingsWindow() {
        settingsController.show()
    }

    private func setShortcutPreference(_ preference: ShortcutPreference) {
        shortcutPreference = preference
        shortcutPreference.save()
        applyShortcutPreference()
        refreshShortcutMenu()
    }

    @objc
    private func promptCustomShortcut() {
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        alert.messageText = "自定义呼出快捷键"
        alert.informativeText = "按下新的组合键。建议包含 Command、Option、Control 或 Shift。按 Esc 取消。"
        alert.addButton(withTitle: "取消")

        let label = NSTextField(labelWithString: "等待按键…")
        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 18, weight: .medium)
        label.frame = NSRect(x: 0, y: 0, width: 260, height: 32)
        alert.accessoryView = label

        var capturedShortcut: KeyboardShortcut?
        var monitor: Any?
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                NSApp.stopModal(withCode: .cancel)
                return nil
            }

            let modifiers = KeyboardShortcut.carbonModifiers(from: event.modifierFlags)
            guard modifiers > 0 else {
                label.stringValue = "请至少包含一个修饰键"
                return nil
            }

            let shortcut = KeyboardShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            capturedShortcut = shortcut
            label.stringValue = shortcut.title
            NSApp.stopModal(withCode: .OK)
            return nil
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }

        guard response == .OK, let capturedShortcut else { return }
        setShortcutPreference(.hotKey(capturedShortcut))
    }

    @objc
    private func useDefaultShortcut() {
        setShortcutPreference(.doubleCommand)
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
