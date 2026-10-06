import Carbon.HIToolbox
import ClipshotCore
import ClipshotTestSupport
import Testing

@testable import ClipshotHotKey

extension CarbonSuite {
    @MainActor
    @Suite("HotKeyController")
    final class HotKeyControllerTests {
        let store = MemoryPreferenceStore()
        let service = CarbonHotKeyService()
        let presses = PressCounter()

        /// Swift Testing releases suite instances off the main thread; Carbon must be torn down on it.
        isolated deinit { service.unregister() }

        /// A controller whose saved combo is `saved` (testA unless a test says otherwise).
        func controller(saved: KeyCombo = .testA) -> HotKeyController {
            let settings = HotKeySettings(store: store)
            settings.combo = saved
            let presses = presses
            return HotKeyController(service: service, settings: settings) { presses.press() }
        }

        /// Proves Carbon really let the combo go: a fresh registration can take it.
        func isFree(_ combo: KeyCombo) -> Bool {
            let probe = CarbonHotKeyService()
            defer { probe.unregister() }
            return (try? probe.register(combo) {}) != nil
        }

        @Test func startRegistersTheSavedCombo() {
            let hotKeys = controller()
            hotKeys.start()
            #expect(service.registeredCombo == .testA)
            #expect(hotKeys.registrationError == nil)
        }

        @Test func aPressOfTheRegisteredComboStartsACapture() async throws {
            controller().start()
            try sendHotKeyPressed(signature: CarbonHotKeyService.signature)
            await waitForPresses(presses, atLeast: 1)
            #expect(presses.value == 1)
        }

        /// Carbon's one refusal (a combo this process already holds) stands in for any failed registration.
        @Test func refusedComboIsReportedOnStart() throws {
            let holder = CarbonHotKeyService()
            defer { holder.unregister() }
            try holder.register(.testA) {}

            let hotKeys = controller()
            hotKeys.start()
            #expect(service.registeredCombo == nil)
            #expect(hotKeys.registrationError == .registrationFailed(hotKeyExistsStatus))
        }

        /// While paused, ⌘P has to reach the frontmost app again (Print), so Carbon must release it.
        @Test func pauseReleasesTheComboAndResumeTakesItBack() {
            let hotKeys = controller()
            hotKeys.start()
            hotKeys.setPaused(true)
            #expect(hotKeys.isPaused)
            #expect(isFree(.testA))

            hotKeys.setPaused(false)
            #expect(service.registeredCombo == .testA)
        }

        /// Otherwise pressing the current combo would start a capture instead of reaching the recorder.
        @Test func recordingReleasesTheCombo() {
            let hotKeys = controller()
            hotKeys.start()
            hotKeys.beginRecording()
            #expect(isFree(.testA))
        }

        @Test func cancelledRecordingBringsTheSavedComboBack() throws {
            let hotKeys = controller()
            hotKeys.start()
            hotKeys.beginRecording()
            try hotKeys.finishRecording(with: nil)
            #expect(service.registeredCombo == .testA)
            #expect(HotKeySettings(store: store).combo == .testA)
        }

        @Test func recordedComboIsRegisteredAndSurvivesARelaunch() throws {
            let hotKeys = controller()
            hotKeys.start()
            hotKeys.beginRecording()
            try hotKeys.finishRecording(with: .testB)
            #expect(service.registeredCombo == .testB)
            #expect(isFree(.testA))
            #expect(HotKeySettings(store: store).combo == .testB)
        }

        /// A refused combo leaves the saved one untouched and the recorder open for another try.
        @Test func refusedComboIsNotSaved() throws {
            let holder = CarbonHotKeyService()
            defer { holder.unregister() }
            try holder.register(.testB) {}

            let hotKeys = controller()
            hotKeys.start()
            hotKeys.beginRecording()
            #expect(throws: HotKeyError.registrationFailed(hotKeyExistsStatus)) {
                try hotKeys.finishRecording(with: .testB)
            }
            #expect(hotKeys.isRecording)
            #expect(HotKeySettings(store: store).combo == .testA)

            try hotKeys.finishRecording(with: nil)
            #expect(service.registeredCombo == .testA)
        }

        /// The launch error goes away once the user has picked a combo that works.
        @Test func recordingAWorkingComboClearsTheStartError() throws {
            let holder = CarbonHotKeyService()
            defer { holder.unregister() }
            try holder.register(.testA) {}

            let hotKeys = controller()
            hotKeys.start()
            hotKeys.beginRecording()
            try hotKeys.finishRecording(with: .testB)
            #expect(hotKeys.registrationError == nil)
            #expect(service.registeredCombo == .testB)
        }

        @Test func cancellingARecordingWhilePausedStaysPaused() throws {
            let hotKeys = controller()
            hotKeys.start()
            hotKeys.setPaused(true)
            hotKeys.beginRecording()
            try hotKeys.finishRecording(with: nil)
            #expect(hotKeys.isPaused)
            #expect(isFree(.testA))
        }

        /// Picking a new shortcut is a clear "I want it on": the pause ends.
        @Test func recordingANewComboWhilePausedResumes() throws {
            let hotKeys = controller()
            hotKeys.start()
            hotKeys.setPaused(true)
            hotKeys.beginRecording()
            try hotKeys.finishRecording(with: .testB)
            #expect(!hotKeys.isPaused)
            #expect(service.registeredCombo == .testB)
        }
    }
}
