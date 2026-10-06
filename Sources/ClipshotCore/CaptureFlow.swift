/// One press of the hotkey: Screen Recording gate → `screencapture -i -c` → did the clipboard change?
///
/// Everything that touches the system comes in as a closure, so the rules are testable without a screen;
/// the app passes CGPreflightScreenCaptureAccess, NSPasteboard.general.changeCount and ScreencaptureRunner.
@MainActor
public final class CaptureFlow {
    private let isPermissionGranted: () -> Bool
    private let clipboardChangeCount: () -> Int
    private let runScreencapture: () async throws -> ScreencaptureResult
    private let isAlertOpen: () -> Bool
    /// True while the selection is on screen; the auto-updater waits for it before quitting Clipshot.
    public private(set) var isCapturing = false

    public init(
        isPermissionGranted: @escaping () -> Bool,
        clipboardChangeCount: @escaping () -> Int,
        runScreencapture: @escaping () async throws -> ScreencaptureResult,
        isAlertOpen: @escaping () -> Bool = { false }
    ) {
        self.isPermissionGranted = isPermissionGranted
        self.clipboardChangeCount = clipboardChangeCount
        self.runScreencapture = runScreencapture
        self.isAlertOpen = isAlertOpen
    }

    public func capture() async -> CaptureOutcome {
        // A second press while the crosshair or the previous press's alert is up would stack a second one on top.
        guard !isCapturing, !isAlertOpen() else { return .busy }
        // Without the grant the tool captures only the wallpaper and the menu bar: never start it.
        guard isPermissionGranted() else { return .permissionMissing }

        isCapturing = true
        defer { isCapturing = false }
        let countBefore = clipboardChangeCount()
        let result: ScreencaptureResult
        do {
            result = try await runScreencapture()
        } catch ScreencaptureError.launchFailed(let message) {
            return .launchFailed(message)
        } catch {
            return .launchFailed(String(describing: error))
        }
        return .classify(
            exitCode: result.exitCode, stderr: result.stderr,
            clipboardChanged: clipboardChangeCount() != countBefore)
    }
}
