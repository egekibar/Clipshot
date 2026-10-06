import ClipshotTestSupport
import Foundation
import Testing

@testable import ClipshotCore

@Suite("HotKeySettings")
struct HotKeySettingsTests {
    let store = MemoryPreferenceStore()

    @Test func freshInstallUsesCommandP() {
        #expect(HotKeySettings(store: store).combo == KeyCombo.defaultCombo)
    }

    @Test func savedComboSurvivesARelaunch() {
        let controlOptionS = KeyCombo(keyCode: 0x01, modifiers: 0x1800, label: "⌃⌥S")
        HotKeySettings(store: store).combo = controlOptionS
        #expect(HotKeySettings(store: store).combo == controlOptionS)
    }

    @Test func unreadableValueFallsBackToCommandP() {
        store.set(Data("not json".utf8), forKey: HotKeySettings.storageKey)
        #expect(HotKeySettings(store: store).combo == KeyCombo.defaultCombo)
    }

    /// A hand-edited or damaged value must never register a bare letter, which would eat that letter everywhere.
    @Test func storedComboThatWouldEatTypingFallsBackToCommandP() throws {
        let bareA = KeyCombo(keyCode: 0x00, modifiers: 0, label: "A")
        store.set(try JSONEncoder().encode(bareA), forKey: HotKeySettings.storageKey)
        #expect(HotKeySettings(store: store).combo == KeyCombo.defaultCombo)
    }
}
