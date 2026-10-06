import Carbon.HIToolbox
import ClipshotCore
import Testing

@testable import ClipshotHotKey

extension CarbonSuite {
    /// Real key presses cannot be synthesised headless without a permission; `sendHotKeyPressed` delivers the
    /// same Carbon event the window server would, which covers everything from the handler onwards.
    @MainActor
    @Suite("CarbonHotKeyService")
    struct CarbonHotKeyServiceTests {
        @Test func registersAndUnregisters() throws {
            let service = CarbonHotKeyService()
            #expect(service.registeredCombo == nil)
            try service.register(.testA) {}
            #expect(service.registeredCombo == .testA)
            service.unregister()
            #expect(service.registeredCombo == nil)
        }

        /// The first combo must really be released, not only forgotten: another registration can take it.
        @Test func secondRegistrationReplacesTheFirst() throws {
            let service = CarbonHotKeyService()
            defer { service.unregister() }
            try service.register(.testA) {}
            try service.register(.testB) {}
            #expect(service.registeredCombo == .testB)

            let other = CarbonHotKeyService()
            defer { other.unregister() }
            try other.register(.testA) {}
        }

        @Test func unregisterIsIdempotentAndRegisteringAgainWorks() throws {
            let service = CarbonHotKeyService()
            service.unregister()
            try service.register(.testA) {}
            service.unregister()
            service.unregister()
            try service.register(.testA) {}
            #expect(service.registeredCombo == .testA)
            service.unregister()
        }

        /// Carbon refuses a combo this process already holds; the refused service must be left clean.
        @Test func comboAlreadyHeldIsRefused() throws {
            let holder = CarbonHotKeyService()
            defer { holder.unregister() }
            try holder.register(.testA) {}

            let second = CarbonHotKeyService()
            #expect(throws: HotKeyError.registrationFailed(hotKeyExistsStatus)) {
                try second.register(.testA) {}
            }
            #expect(second.registeredCombo == nil)
        }

        @Test func pressRunsTheHandler() async throws {
            let service = CarbonHotKeyService()
            defer { service.unregister() }
            let presses = PressCounter()
            try service.register(.testA) { presses.press() }

            #expect(try sendHotKeyPressed(signature: CarbonHotKeyService.signature) == noErr)
            await waitForPresses(presses, atLeast: 1)
            #expect(presses.value == 1)
        }

        /// Hotkeys registered by anything else in the process carry another signature and must pass through.
        @Test func foreignHotKeysAreLeftAlone() async throws {
            let service = CarbonHotKeyService()
            defer { service.unregister() }
            let presses = PressCounter()
            try service.register(.testA) { presses.press() }

            let foreign: OSType = 0x4F54_4852  // 'OTHR'
            #expect(try sendHotKeyPressed(signature: foreign) == OSStatus(eventNotHandledErr))
            // Our own press is queued behind any call the foreign one could have caused.
            try sendHotKeyPressed(signature: CarbonHotKeyService.signature)
            await waitForPresses(presses, atLeast: 1)
            #expect(presses.value == 1)
        }

        @Test func noHandlerRunsAfterUnregister() throws {
            let service = CarbonHotKeyService()
            try service.register(.testA) {}
            service.unregister()
            #expect(try sendHotKeyPressed(signature: CarbonHotKeyService.signature) == OSStatus(eventNotHandledErr))
        }
    }
}
