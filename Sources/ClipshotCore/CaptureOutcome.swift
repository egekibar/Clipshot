/// What one press of the hotkey ended in. The app turns this into feedback; the rules live here.
public enum CaptureOutcome: Equatable, Sendable {
    /// The selection is on the clipboard.
    case copied
    /// Esc, or a selection that captured nothing. Not an error: nothing is shown.
    case cancelled
    /// A selection was already on screen, so this press was dropped.
    case busy
    /// Screen Recording is not granted; screencapture was not started.
    case permissionMissing
    /// screencapture reported an error. `stderr` is shown to the user as is.
    case failed(exitCode: Int32, stderr: String)
    /// screencapture could not be started at all.
    case launchFailed(String)

    /// Maps one finished `screencapture -i -c` run. Esc is exit 1 with an empty stderr (Shotcue research §2.3),
    /// and only a clipboard that changed during the run proves the selection was copied.
    public static func classify(exitCode: Int32, stderr: String, clipboardChanged: Bool) -> CaptureOutcome {
        switch exitCode {
        case 0: clipboardChanged ? .copied : .cancelled
        case 1 where stderr.isEmpty: .cancelled
        default: .failed(exitCode: exitCode, stderr: stderr)
        }
    }
}
