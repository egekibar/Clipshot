import AppKit
import ClipshotCore
import ClipshotHistory
import ClipshotMarkup
import ClipshotMarkupUI

/// Runs one capture for a hotkey press or a menu click, turns its outcome into feedback, keeps the screenshot in
/// Geçmiş and opens the marking panel over the region that was just copied. It also opens Geçmiş's screenshots in
/// that same panel.
final class CaptureController {
    /// The menu bar's ✓.
    var onCopied: () -> Void = {}
    /// After every press is fully over (its alert or marking panel closed): a waiting update may install now.
    var onFinished: () -> Void = {}

    private let history: HistoryArchive
    private let flow = CaptureFlow(
        isPermissionGranted: { ScreenRecordingPermission.isGranted },
        clipboardChangeCount: { NSPasteboard.general.changeCount },
        runScreencapture: { try await ScreencaptureRunner().run() },
        isAlertOpen: { NSApp.modalWindow != nil })
    private let tracker = SelectionTracker()
    /// The Geçmiş item the marking panel shows, and its pixels per point (for the clipboard copy).
    private var session: (itemID: UUID, scale: CGFloat)?
    private lazy var markup = MarkupPanelController { [unowned self] result in markupFinished(result) }

    init(history: HistoryArchive) {
        self.history = history
    }

    /// A selection or the marking panel is on screen.
    var isBusy: Bool { flow.isCapturing || markup.isOpen }

    func begin() {
        // The crosshair is already up; the flow drops this press, and the drag being tracked stays untouched.
        guard !flow.isCapturing else { return }
        // ⌘P while marking: the marks are kept and the next selection starts.
        markup.finish(.dismiss)
        tracker.begin()
        Task {
            let outcome = await flow.capture()
            Alerts.fromRunLoop { [self] in report(outcome, selection: tracker.end()) }
        }
    }

    /// A screenshot from Geçmiş, with its marks, in the marking panel: centered on the screen under the pointer at the
    /// screenshot's own size. Kopyala puts it on the clipboard.
    func open(_ item: HistoryItem) {
        guard !flow.isCapturing, let image = history.image(of: item.id) else { return }
        let screen = Self.screen(containing: nil)
        let placement = MarkupGeometry.placement(
            imagePixels: CGSize(width: image.width, height: image.height), selection: nil,
            screen: MarkupGeometry.Screen(frame: screen.frame, visibleFrame: screen.visibleFrame, scale: item.scale))
        // A panel still open finishes first, under its own session; this one starts after.
        markup.present(
            image: image, marks: item.marks, clipboardHasImage: false, placement: placement,
            visibleFrame: screen.visibleFrame)
        session = (item.id, item.scale)
    }

    /// Geçmiş's "Kopyala": the screenshot as it was left, marks included, without opening it.
    func copy(_ item: HistoryItem) {
        guard let image = history.image(of: item.id) else { return }
        let marked = item.marks.isEmpty ? image : MarkupRenderer.render(image, marks: item.marks, scale: item.scale)
        if let marked, ClipboardImage.write(marked, scale: item.scale) { onCopied() }
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

    /// Keeps the region just copied in Geçmiş and opens the marking panel over it; false when the clipboard holds no
    /// readable image.
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
        let scale = CGFloat(image.width) / placement.imageSize.width
        let itemID = history.add(image, scale: scale)
        markup.present(image: image, placement: placement, visibleFrame: screen.visibleFrame)
        session = (itemID, scale)
        return true
    }

    private func markupFinished(_ result: MarkupResult) {
        let finished = session
        session = nil
        if let image = result.clipboard {
            if ClipboardImage.write(image, scale: finished?.scale ?? 2) {
                onCopied()
            } else {
                AppLog.app.error("could not put the marked screenshot on the clipboard")
            }
        }
        if let marks = result.marks, let finished { history.update(finished.itemID, marks: marks) }
        onFinished()
    }

    /// The screen the selection is on, else the one under the pointer.
    private static func screen(containing selection: CGRect?) -> NSScreen {
        let point = selection.map { CGPoint(x: $0.midX, y: $0.midY) } ?? NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}
