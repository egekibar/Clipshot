import Foundation
import Testing

@testable import ClipshotCore

@Suite("ScreencaptureRunner")
struct ScreencaptureRunnerTests {
    /// The fake stands in for /usr/sbin/screencapture; the scenario comes from the environment.
    func runner(_ scenario: String, extra: [String: String] = [:]) -> ScreencaptureRunner {
        ScreencaptureRunner(
            executableURL: TestPaths.fixture("fake-screencapture.sh"),
            environment: ["FAKE_SCREENCAPTURE_SCENARIO": scenario].merging(extra) { $1 })
    }

    @Test func defaultExecutableIsSystemScreencapture() {
        #expect(ScreencaptureRunner().executableURL.path == "/usr/sbin/screencapture")
    }

    /// -i: the interactive crosshair · -c: the result goes to the clipboard, never to a file on the Desktop.
    @Test func asksForAnInteractiveSelectionOntoTheClipboard() async throws {
        let argsFile = TestPaths.scratchFile("txt")
        defer { try? FileManager.default.removeItem(at: argsFile) }
        _ = try await runner("success", extra: ["FAKE_SCREENCAPTURE_ARGS": argsFile.path]).run()
        let args = try String(contentsOf: argsFile, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(args == ["-i", "-c"])
    }

    @Test func successReportsExitZero() async throws {
        #expect(try await runner("success").run() == ScreencaptureResult(exitCode: 0, stderr: ""))
    }

    @Test func escReportsExitOneWithEmptyStderr() async throws {
        #expect(try await runner("cancel").run() == ScreencaptureResult(exitCode: 1, stderr: ""))
    }

    @Test func errorCarriesTheTrimmedMessage() async throws {
        #expect(
            try await runner("error").run()
                == ScreencaptureResult(exitCode: 2, stderr: "screencapture: could not create image"))
    }

    /// Waiting for the exit before reading stderr would deadlock once the child fills the pipe buffer.
    @Test(.timeLimit(.minutes(1)))
    func largeStderrIsDrainedWhileTheToolRuns() async throws {
        let result = try await runner("flood").run()
        #expect(result.exitCode == 3)
        #expect(result.stderr.count == 200_000)
    }

    @Test func missingExecutableThrowsLaunchFailed() async throws {
        let missing = ScreencaptureRunner(executableURL: URL(fileURLWithPath: "/nonexistent/screencapture"))
        let error = await #expect(throws: ScreencaptureError.self) { try await missing.run() }
        guard case .launchFailed = try #require(error) else {
            Issue.record("expected launchFailed, got \(String(describing: error))")
            return
        }
    }
}
