import AppKit
import ClipshotCore
import ClipshotHotKey
import ClipshotUpdater

/// Composition root: the capture, the global shortcut, the menu bar item, the shortcut recorder, the login item and
/// the auto-updater.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let capture = CaptureController()
    private let preferences = AppPreferences()
    private var hotKeys: HotKeyController!
    private var statusMenu: StatusMenuController!
    private var recorder: ShortcutRecorderController!
    private var loginItem: LoginItem?
    private var updater: AutoUpdater?
    private var updateLoop: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let capture = capture
        hotKeys = HotKeyController(settings: HotKeySettings()) {
            // Carbon already calls this on the main queue; the hop only makes the isolation explicit.
            Task { @MainActor in capture.begin() }
        }
        loginItem = Self.makeLoginItem()
        updater = makeUpdater()
        statusMenu = StatusMenuController(
            hotKeys: hotKeys, loginItem: loginItem, updater: updater,
            actions: StatusMenuActions(
                capture: { capture.begin() },
                changeShortcut: { [unowned self] in recorder.show() },
                hideIcon: { [unowned self] in hideIcon() },
                checkForUpdates: { [unowned self] in checkForUpdates() }))
        recorder = ShortcutRecorderController(hotKeys: hotKeys) { [unowned self] in
            statusMenu.refresh()
            updater?.installIfIdle()
        }
        capture.onCopied = { [unowned self] in statusMenu.flashCopied() }
        capture.onFinished = { [unowned self] in updater?.installIfIdle() }

        hotKeys.start()
        statusMenu.refresh()
        statusMenu.setIconVisible(!preferences.isMenuBarIconHidden)
        if let error = hotKeys.registrationError {
            let label = hotKeys.combo.label
            let reason = String(describing: error)
            AppLog.app.error("shortcut \(label, privacy: .public) not registered: \(reason, privacy: .public)")
            if Alerts.shortcutUnavailable(hotKeys.combo, error: error) { recorder.show() }
        } else {
            AppLog.app.notice("shortcut \(self.hotKeys.combo.label, privacy: .public) registered")
        }

        setUpLoginItem()
        // The system asks for Screen Recording once, at the first launch, instead of on the first ⌘P.
        if !ScreenRecordingPermission.isGranted { ScreenRecordingPermission.request() }
        startUpdateLoop()
    }

    /// Opening Clipshot again (Spotlight, Finder, Launchpad) brings a hidden icon back and opens its menu.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if preferences.isMenuBarIconHidden {
            preferences.isMenuBarIconHidden = false
            statusMenu.setIconVisible(true)
        }
        // After the icon has been laid out in the menu bar.
        DispatchQueue.main.async { [statusMenu] in statusMenu?.openMenu() }
        return false
    }

    private func hideIcon() {
        guard Alerts.confirmHidingIcon() else { return }
        preferences.isMenuBarIconHidden = true
        statusMenu.setIconVisible(false)
    }

    // MARK: - Login item

    private static func makeLoginItem() -> LoginItem? {
        let bundle = Bundle.main
        guard bundle.bundleURL.pathExtension == "app", let bundleID = bundle.bundleIdentifier else { return nil }
        let agents = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        return LoginItem(label: bundleID, appURL: bundle.bundleURL, agentsDirectory: agents)
    }

    /// "Girişte Aç" is on from the first launch; later launches only keep an enabled agent pointing at this bundle.
    private func setUpLoginItem() {
        guard let loginItem else { return }
        do {
            if !preferences.hasConfiguredLoginItem {
                try loginItem.enable()
                preferences.hasConfiguredLoginItem = true
                AppLog.app.notice("login item enabled")
            } else if loginItem.isEnabled {
                try loginItem.enable()
            }
        } catch {
            AppLog.app.error("login item: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Updates

    private func makeUpdater() -> AutoUpdater? {
        let bundle = Bundle.main
        guard bundle.bundleURL.pathExtension == "app", let bundleID = bundle.bundleIdentifier,
            let repo = bundle.object(forInfoDictionaryKey: "ClipshotUpdateRepo") as? String,
            let versionText = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let version = AppVersion(versionText)
        else { return nil }
        let capture = capture
        let installedApp = bundle.bundleURL
        return AutoUpdater(
            current: version, feed: GitHubReleaseFeed(repo: repo),
            installer: DMGUpdateInstaller(installedApp: installedApp, bundleID: bundleID),
            preferences: preferences,
            // Never quit under an open selection, the shortcut recorder or an alert.
            isIdle: { [unowned self] in !capture.isBusy && !hotKeys.isRecording && NSApp.modalWindow == nil },
            install: { staged in
                try BundleSwapper.start(
                    waitingFor: ProcessInfo.processInfo.processIdentifier, staged: staged, target: installedApp)
                AppLog.app.notice("update staged; quitting so it can be swapped in")
                NSApp.terminate(nil)
            })
    }

    /// The first check ~10 s after launch, then an hourly tick; the updater itself decides whether six hours passed.
    private func startUpdateLoop() {
        guard let updater else { return }
        updateLoop = Task {
            try? await Task.sleep(for: .seconds(10))
            while !Task.isCancelled {
                if let result = await updater.tick() { Self.log(result) }
                try? await Task.sleep(for: .seconds(3600))
            }
        }
    }

    private func checkForUpdates() {
        guard let updater else { return }
        Task {
            let result = await updater.checkNow()
            Self.log(result)
            switch result {
            case .upToDate(let version): Alerts.upToDate(version)
            case .failed(let error): Alerts.updateFailed(error)
            case .updating, .busy: break  // Clipshot restarts on its own once the new version is in place
            }
        }
    }

    private static func log(_ result: AutoUpdater.CheckResult) {
        switch result {
        case .upToDate(let version): AppLog.app.notice("update check: \(version, privacy: .public) is the newest")
        case .updating(let version): AppLog.app.notice("update check: installing \(version, privacy: .public)")
        case .busy: break
        case .failed(let error):
            AppLog.app.error("update check failed: \(String(describing: error), privacy: .public)")
        }
    }
}
