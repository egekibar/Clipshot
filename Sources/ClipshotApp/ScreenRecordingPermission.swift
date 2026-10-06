import AppKit
import CoreGraphics

/// Screen Recording (TCC). screencapture is checked against Clipshot because Clipshot spawns it.
enum ScreenRecordingPermission {
    /// Never prompts. A denial and "never asked" both read as false.
    static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows the system prompt once; a process that was denied before is not asked again (CoreGraphics header).
    static func request() { _ = CGRequestScreenCaptureAccess() }

    static func openSystemSettings() {
        let pane = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        NSWorkspace.shared.open(URL(string: pane)!)
    }
}

enum Relauncher {
    /// A Screen Recording grant only counts from the next launch: quit, and open the bundle again once this
    /// process is gone.
    static func relaunch() {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else { return }
        let relauncher = Process()
        relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
        // `$1` = our pid, `$2` = bundle path: positional parameters, so the path is never re-parsed.
        relauncher.arguments = [
            "-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$2\"",
            "clipshot-relaunch", String(ProcessInfo.processInfo.processIdentifier), bundleURL.path,
        ]
        relauncher.standardInput = FileHandle.nullDevice
        relauncher.standardOutput = FileHandle.nullDevice
        relauncher.standardError = FileHandle.nullDevice
        do {
            try relauncher.run()
        } catch {
            AppLog.app.error("relaunch failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        NSApp.terminate(nil)
    }
}
