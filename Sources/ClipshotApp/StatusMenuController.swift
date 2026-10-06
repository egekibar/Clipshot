import AppKit
import ClipshotCore
import ClipshotHotKey
import ClipshotUpdater

/// What the menu's items do beyond what the menu can do on its own.
struct StatusMenuActions {
    var capture: () -> Void
    var showHistory: () -> Void
    var changeShortcut: () -> Void
    var hideIcon: () -> Void
    var showSettings: () -> Void
    var checkForUpdates: () -> Void
}

/// The menu bar item. The icon shows the state (ready, paused, shortcut not working, just copied) and the menu
/// is rebuilt every time it opens, so it never shows a stale shortcut, permission, login or update state.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let hotKeys: HotKeyController
    /// nil when Clipshot does not run from an app bundle (a bare `swift run`).
    private let loginItem: LoginItem?
    private let updater: AutoUpdater?
    private let actions: StatusMenuActions
    private var flashTask: Task<Void, Never>?

    init(hotKeys: HotKeyController, loginItem: LoginItem?, updater: AutoUpdater?, actions: StatusMenuActions) {
        self.hotKeys = hotKeys
        self.loginItem = loginItem
        self.updater = updater
        self.actions = actions
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

    /// "Menü Çubuğundan Gizle": the shortcut keeps working without the icon.
    func setIconVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    /// Opens the menu as if the icon had been clicked (Clipshot was opened again from Spotlight or Finder).
    func openMenu() {
        statusItem.button?.performClick(nil)
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
        menu.addItem(item("Geçmiş…", action: #selector(historyClicked)))
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
        if let loginItem {
            let login = item("Girişte Aç", action: #selector(loginItemClicked))
            login.state = loginItem.isEnabled ? .on : .off
            menu.addItem(login)
        }
        menu.addItem(item("Menü Çubuğundan Gizle…", action: #selector(hideClicked)))
        menu.addItem(item("Ayarlar…", action: #selector(settingsClicked)))
        menu.addItem(.separator())
        menu.addItem(info(versionLine))
        if updater != nil {
            menu.addItem(item("Güncellemeleri Denetle…", action: #selector(checkForUpdatesClicked)))
        }
        menu.addItem(item("Clipshot'tan Çık", action: #selector(quitClicked), key: "q"))
    }

    private var shortcutLine: String {
        let label = hotKeys.combo.label
        if hotKeys.isRecording { return "Kısayol: yeni kombinasyon bekleniyor…" }
        if hotKeys.isPaused { return "Kısayol: \(label) (duraklatıldı)" }
        if hotKeys.registrationError != nil { return "Kısayol: \(label) (çalışmıyor)" }
        return "Kısayol: \(label)"
    }

    private var versionLine: String {
        let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        switch updater?.phase {
        case .checking: return "Clipshot \(installed) · denetleniyor…"
        case .downloading(let version): return "Clipshot \(installed) · \(version) indiriliyor…"
        case .readyToInstall(let version), .installing(let version):
            return "Clipshot \(installed) · \(version) kuruluyor…"
        case .idle, nil: return "Clipshot \(installed)"
        }
    }

    @objc private func captureClicked() { actions.capture() }
    @objc private func changeShortcutClicked() { actions.changeShortcut() }
    @objc private func hideClicked() { actions.hideIcon() }
    @objc private func historyClicked() { actions.showHistory() }
    @objc private func settingsClicked() { actions.showSettings() }
    @objc private func checkForUpdatesClicked() { actions.checkForUpdates() }
    @objc private func permissionClicked() { Alerts.screenRecordingMissing() }
    @objc private func quitClicked() { NSApp.terminate(nil) }

    @objc private func pauseClicked() {
        hotKeys.setPaused(!hotKeys.isPaused)
        refresh()
    }

    @objc private func loginItemClicked() {
        guard let loginItem else { return }
        do {
            if loginItem.isEnabled { try loginItem.disable() } else { try loginItem.enable() }
        } catch {
            AppLog.app.error("login item: \(error.localizedDescription, privacy: .public)")
            Alerts.loginItemFailed(error)
        }
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
