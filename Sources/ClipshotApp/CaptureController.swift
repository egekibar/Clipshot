import AppKit
import ClipshotCore

/// Runs one capture for a hotkey press or a menu click and turns its outcome into feedback.
final class CaptureController {
    /// The menu bar's ✓.
    var onCopied: () -> Void = {}
    /// After every press, whatever its outcome (and after its alert closed): a waiting update may install now.
    var onFinished: () -> Void = {}

    private let flow = CaptureFlow(
        isPermissionGranted: { ScreenRecordingPermission.isGranted },
        clipboardChangeCount: { NSPasteboard.general.changeCount },
        runScreencapture: { try await ScreencaptureRunner().run() })

    /// A selection is on screen.
    var isBusy: Bool { flow.isCapturing }

    func begin() {
        Task {
            let outcome = await flow.capture()
            switch outcome {
            case .copied:
                onCopied()
            case .cancelled, .busy:
                break
            case .permissionMissing:
                Alerts.screenRecordingMissing()
            case .failed(let exitCode, let stderr):
                AppLog.app.error("screencapture exited \(exitCode, privacy: .public): \(stderr, privacy: .private)")
                Alerts.captureFailed(stderr.isEmpty ? "screencapture \(exitCode) koduyla çıktı." : stderr)
            case .launchFailed(let message):
                AppLog.app.error("screencapture did not start: \(message, privacy: .public)")
                Alerts.captureFailed("screencapture başlatılamadı: \(message)")
            }
            onFinished()
        }
    }
}
