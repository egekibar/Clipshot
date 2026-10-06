import Testing

@testable import ClipshotCore

@MainActor
@Suite("CaptureFlow")
struct CaptureFlowTests {
    /// screencapture writes the clipboard while it runs, which bumps the pasteboard's change count.
    @Test func copiedWhenTheClipboardChangedDuringTheRun() async {
        var changeCount = 7
        let flow = CaptureFlow(
            isPermissionGranted: { true },
            clipboardChangeCount: { changeCount },
            runScreencapture: {
                changeCount += 1
                return ScreencaptureResult(exitCode: 0, stderr: "")
            })
        #expect(await flow.capture() == .copied)
    }

    @Test func untouchedClipboardAfterExitZeroIsACancel() async {
        let flow = CaptureFlow(
            isPermissionGranted: { true },
            clipboardChangeCount: { 7 },
            runScreencapture: { ScreencaptureResult(exitCode: 0, stderr: "") })
        #expect(await flow.capture() == .cancelled)
    }

    @Test func failureCarriesTheToolsExitCodeAndMessage() async {
        let flow = CaptureFlow(
            isPermissionGranted: { true },
            clipboardChangeCount: { 7 },
            runScreencapture: { ScreencaptureResult(exitCode: 2, stderr: "could not create image") })
        #expect(await flow.capture() == .failed(exitCode: 2, stderr: "could not create image"))
    }

    /// Without the grant the tool would capture only the wallpaper, so it must not start at all.
    @Test func withoutScreenRecordingTheToolNeverStarts() async {
        var runs = 0
        let flow = CaptureFlow(
            isPermissionGranted: { false },
            clipboardChangeCount: { 7 },
            runScreencapture: {
                runs += 1
                return ScreencaptureResult(exitCode: 0, stderr: "")
            })
        #expect(await flow.capture() == .permissionMissing)
        #expect(runs == 0)
    }

    /// A second press while the crosshair is up would stack a second selection on top of the first.
    @Test func pressWhileSelectingIsDropped() async throws {
        var release: CheckedContinuation<Void, Never>?
        var runs = 0
        let flow = CaptureFlow(
            isPermissionGranted: { true },
            clipboardChangeCount: { 7 },
            runScreencapture: {
                runs += 1
                // Stands in for the user still dragging: the run only ends when the test says so.
                await withCheckedContinuation { release = $0 }
                return ScreencaptureResult(exitCode: 1, stderr: "")
            })

        let first = Task { await flow.capture() }
        // Let the first press reach the tool; bounded, so a flow that never starts it fails instead of hanging.
        for _ in 0..<1000 where release == nil { await Task.yield() }
        let selecting = try #require(release, "the first press never started screencapture")

        #expect(await flow.capture() == .busy)
        selecting.resume()
        #expect(await first.value == .cancelled)
        #expect(runs == 1)
    }

    @Test func nextPressAfterAFinishedSelectionRunsAgain() async {
        var runs = 0
        let flow = CaptureFlow(
            isPermissionGranted: { true },
            clipboardChangeCount: { 7 },
            runScreencapture: {
                runs += 1
                return ScreencaptureResult(exitCode: 1, stderr: "")
            })
        _ = await flow.capture()
        _ = await flow.capture()
        #expect(runs == 2)
    }

    @Test func launchFailureIsReported() async {
        let flow = CaptureFlow(
            isPermissionGranted: { true },
            clipboardChangeCount: { 7 },
            runScreencapture: { throw ScreencaptureError.launchFailed("no such file") })
        #expect(await flow.capture() == .launchFailed("no such file"))
    }

    /// Even when the launch throws, the busy flag must come down or the hotkey would be dead from then on.
    @Test func pressAfterALaunchFailureRunsAgain() async {
        var runs = 0
        let flow = CaptureFlow(
            isPermissionGranted: { true },
            clipboardChangeCount: { 7 },
            runScreencapture: {
                runs += 1
                throw ScreencaptureError.launchFailed("no such file")
            })
        _ = await flow.capture()
        _ = await flow.capture()
        #expect(runs == 2)
    }
}
