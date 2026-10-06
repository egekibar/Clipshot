import Foundation
import Testing

@testable import ClipshotCore

/// A private defaults domain per test, removed again when the test ends.
final class ScratchDefaults {
    let name = "clipshot-tests-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() { defaults = UserDefaults(suiteName: name)! }
    deinit { defaults.removePersistentDomain(forName: name) }
}

@Suite("HotKeySettings")
struct HotKeySettingsTests {
    let scratch = ScratchDefaults()

    @Test func freshInstallUsesCommandP() {
        #expect(HotKeySettings(defaults: scratch.defaults).combo == KeyCombo.defaultCombo)
    }

    @Test func savedComboSurvivesARelaunch() {
        let controlOptionS = KeyCombo(keyCode: 0x01, modifiers: 0x1800, label: "⌃⌥S")
        HotKeySettings(defaults: scratch.defaults).combo = controlOptionS
        #expect(HotKeySettings(defaults: scratch.defaults).combo == controlOptionS)
    }

    @Test func unreadableValueFallsBackToCommandP() {
        scratch.defaults.set(Data("not json".utf8), forKey: HotKeySettings.storageKey)
        #expect(HotKeySettings(defaults: scratch.defaults).combo == KeyCombo.defaultCombo)
    }

    /// A hand-edited or damaged value must never register a bare letter, which would eat that letter everywhere.
    @Test func storedComboThatWouldEatTypingFallsBackToCommandP() throws {
        let bareA = KeyCombo(keyCode: 0x00, modifiers: 0, label: "A")
        scratch.defaults.set(try JSONEncoder().encode(bareA), forKey: HotKeySettings.storageKey)
        #expect(HotKeySettings(defaults: scratch.defaults).combo == KeyCombo.defaultCombo)
    }
}
