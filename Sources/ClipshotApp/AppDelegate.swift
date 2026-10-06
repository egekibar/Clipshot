import AppKit
import ClipshotCore
import ClipshotHotKey

/// Composition root: the capture, the global shortcut, the menu bar item and the shortcut recorder.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let capture = CaptureController()
    private var hotKeys: HotKeyController!
    private var statusMenu: StatusMenuController!
    private var recorder: ShortcutRecorderController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let capture = capture
        hotKeys = HotKeyController(settings: HotKeySettings()) {
            // Carbon already calls this on the main queue; the hop only makes the isolation explicit.
            Task { @MainActor in capture.begin() }
        }
        statusMenu = StatusMenuController(
            hotKeys: hotKeys,
            onCapture: { capture.begin() },
            onChangeShortcut: { [unowned self] in recorder.show() })
        recorder = ShortcutRecorderController(hotKeys: hotKeys) { [unowned self] in statusMenu.refresh() }
        capture.onCopied = { [unowned self] in statusMenu.flashCopied() }

        hotKeys.start()
        statusMenu.refresh()
        if let error = hotKeys.registrationError {
            let label = hotKeys.combo.label
            let reason = String(describing: error)
            AppLog.app.error("shortcut \(label, privacy: .public) not registered: \(reason, privacy: .public)")
            if Alerts.shortcutUnavailable(hotKeys.combo, error: error) { recorder.show() }
        } else {
            AppLog.app.notice("shortcut \(self.hotKeys.combo.label, privacy: .public) registered")
        }

        // The system asks for Screen Recording once, at the first launch, instead of on the first ⌘P.
        if !ScreenRecordingPermission.isGranted { ScreenRecordingPermission.request() }
    }
}
