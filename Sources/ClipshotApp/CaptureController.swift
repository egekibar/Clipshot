import AppKit
import ClipshotCore
import ClipshotMarkup
import ClipshotMarkupUI

/// Runs one capture for a hotkey press or a menu click, turns its outcome into feedback, and opens the marking panel
/// over the region that was just copied.
final class CaptureController {
    /// The menu bar's ✓.
    var onCopied: () -> Void = {}
    /// After every press is fully over (its alert or marking panel closed): a waiting update may install now.
    var onFinished: () -> Void = {}

    private let flow = CaptureFlow(
        isPermissionGranted: { ScreenRecordingPermission.isGranted },
        clipboardChangeCount: { NSPasteboard.general.changeCount },
        runScreencapture: { try await ScreencaptureRunner().run() },
        isAlertOpen: { NSApp.modalWindow != nil })
    private let tracker = SelectionTracker()
    /// Pixels per point of the screenshot in the marking panel, for the clipboard copy.
    private var markupScale: CGFloat = 2
    private lazy var markup = MarkupPanelController(
        onCopy: { [unowned self] image in copyMarked(image) },
        onClose: { [unowned self] in onFinished() })

    /// A selection or the marking panel is on screen.
    var isBusy: Bool { flow.isCapturing || markup.isOpen }

    func begin() {
        // The crosshair is already up; the flow drops this press, and the drag being tracked stays untouched.
        guard !flow.isCapturing else { return }
        // ⌘P while marking: the marks are kept and the next selection starts.
        markup.finish(keepingMarks: true)
        tracker.begin()
        Task {
            let outcome = await flow.capture()
            Alerts.fromRunLoop { [self] in report(outcome, selection: tracker.end()) }
        }
    }

    private func report(_ outcome: CaptureOutcome, selection: CGRect?) {
        switch outcome {
        case .copied:
            onCopied()
            // The panel's close is the end of this press; `onFinished` comes from there.
            if presentMarkup(selection: selection) { return }
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

    /// Opens the marking panel over the region just copied; false when the clipboard holds no readable image.
    private func presentMarkup(selection: CGRect?) -> Bool {
        guard let image = ClipboardImage.read() else {
            AppLog.app.error("no readable image on the clipboard after a capture")
            return false
        }
        let screen = Self.screen(containing: selection)
        let placement = MarkupGeometry.placement(
            imagePixels: CGSize(width: image.width, height: image.height), selection: selection,
            screen: MarkupGeometry.Screen(
                frame: screen.frame, visibleFrame: screen.visibleFrame, scale: screen.backingScaleFactor))
        markupScale = CGFloat(image.width) / placement.imageSize.width
        markup.present(image: image, placement: placement, visibleFrame: screen.visibleFrame)
        return true
    }

    private func copyMarked(_ image: CGImage) {
        if ClipboardImage.write(image, scale: markupScale) {
            onCopied()
        } else {
            AppLog.app.error("could not put the marked screenshot on the clipboard")
        }
    }

    /// The screen the selection is on, else the one under the pointer.
    private static func screen(containing selection: CGRect?) -> NSScreen {
        let point = selection.map { CGPoint(x: $0.midX, y: $0.midY) } ?? NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}
