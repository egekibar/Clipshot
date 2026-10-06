import AppKit
import ClipshotCore
import ClipshotHotKey

/// The menu bar item. The icon shows the state (ready, paused, shortcut not working, just copied) and the menu
/// is rebuilt every time it opens, so it never shows a stale shortcut or permission state.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let hotKeys: HotKeyController
    private let onCapture: () -> Void
    private let onChangeShortcut: () -> Void
    private var flashTask: Task<Void, Never>?

    init(hotKeys: HotKeyController, onCapture: @escaping () -> Void, onChangeShortcut: @escaping () -> Void) {
        self.hotKeys = hotKeys
        self.onCapture = onCapture
        self.onChangeShortcut = onChangeShortcut
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refresh()
    }

    /// Brings the icon in line with the shortcut's state; call after anything that changes it.
    func refresh() {
        guard flashTask == nil else { return }  // the ✓ puts the icon back itself
        let symbol = hotKeys.registrationError == nil ? "rectangle.dashed.and.paperclip" : "exclamationmark.triangle"
        setIcon(symbol)
        statusItem.button?.appearsDisabled = hotKeys.isPaused
        statusItem.button?.toolTip = "Clipshot · \(hotKeys.combo.label)"
    }

    /// A short ✓ in the menu bar: the selection is on the clipboard.
    func flashCopied() {
        flashTask?.cancel()
        setIcon("checkmark.circle.fill")
        statusItem.button?.appearsDisabled = false
        flashTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            flashTask = nil
            refresh()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(item("Seçili Alanı Kopyala", action: #selector(captureClicked)))
        menu.addItem(.separator())
        menu.addItem(info(shortcutLine))
        if let error = hotKeys.registrationError { menu.addItem(info(Alerts.describe(error))) }
        menu.addItem(item("Kısayolu Değiştir…", action: #selector(changeShortcutClicked)))
        let pause = item("Kısayolu Duraklat", action: #selector(pauseClicked))
        pause.state = hotKeys.isPaused ? .on : .off
        menu.addItem(pause)
        menu.addItem(.separator())
        if !ScreenRecordingPermission.isGranted {
            menu.addItem(item("Ekran Kaydı İzni Ver…", action: #selector(permissionClicked)))
        }
        menu.addItem(item("Clipshot'tan Çık", action: #selector(quitClicked), key: "q"))
    }

    private var shortcutLine: String {
        let label = hotKeys.combo.label
        if hotKeys.isPaused { return "Kısayol: \(label) (duraklatıldı)" }
        if hotKeys.registrationError != nil { return "Kısayol: \(label) (çalışmıyor)" }
        return "Kısayol: \(label)"
    }

    @objc private func captureClicked() { onCapture() }
    @objc private func changeShortcutClicked() { onChangeShortcut() }
    @objc private func permissionClicked() { Alerts.screenRecordingMissing() }
    @objc private func quitClicked() { NSApp.terminate(nil) }

    @objc private func pauseClicked() {
        hotKeys.setPaused(!hotKeys.isPaused)
        refresh()
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func setIcon(_ symbol: String) {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Clipshot")
        image?.isTemplate = true
        statusItem.button?.image = image
    }
}
