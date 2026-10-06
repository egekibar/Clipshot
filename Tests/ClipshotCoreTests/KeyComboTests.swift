import Foundation
import Testing

@testable import ClipshotCore

@Suite("KeyCombo")
struct KeyComboTests {
    /// The user asked for ⌘P: kVK_ANSI_P is 0x23 and cmdKey is 1 << 8 in HIToolbox/Events.h.
    @Test func defaultIsCommandP() {
        let combo = KeyCombo.defaultCombo
        #expect(combo.keyCode == 0x23)
        #expect(combo.modifiers == 0x0100)
        #expect(combo.label == "⌘P")
    }

    /// Recording ⌘ + the P key must give back the very combo the app starts with, or "Varsayılan" and a
    /// recorded ⌘P would be two different shortcuts.
    @Test func recordingCommandPGivesTheDefault() {
        let command = KeyCombo.modifierMask(command: true, shift: false, option: false, control: false)
        #expect(KeyCombo.recorded(keyCode: 0x23, modifiers: command, characters: "p") == KeyCombo.defaultCombo)
    }

    @Test func modifierMaskUsesCarbonBits() {
        #expect(KeyCombo.modifierMask(command: true, shift: true, option: false, control: false) == 0x0300)
        #expect(KeyCombo.modifierMask(command: false, shift: false, option: true, control: true) == 0x1800)
    }

    @Test func labelListsModifiersInMacOrderThenTheKey() {
        let all = KeyCombo.modifierMask(command: true, shift: true, option: true, control: true)
        let combo = KeyCombo.recorded(keyCode: 0x00, modifiers: all, characters: "a")
        #expect(combo == KeyCombo(keyCode: 0x00, modifiers: 0x1B00, label: "⌃⌥⇧⌘A"))
    }

    @Test func specialKeysAreNamedByKeyCode() {
        let command: UInt32 = 0x0100
        #expect(KeyCombo.recorded(keyCode: 0x24, modifiers: command, characters: "\r")?.label == "⌘↩")
        #expect(KeyCombo.recorded(keyCode: 0x7E, modifiers: command, characters: "")?.label == "⌘↑")
        #expect(KeyCombo.recorded(keyCode: 0x60, modifiers: command, characters: "")?.label == "⌘F5")
        #expect(KeyCombo.recorded(keyCode: 0x31, modifiers: 0x0800, characters: " ")?.label == "⌥Space")
    }

    /// On a Turkish layout the key next to Ş types "i" and the one under the US I types "ı":
    /// their labels must read İ and I, not both I.
    @Test func lettersAreUppercasedForTheUsersLanguage() {
        let command: UInt32 = 0x0100
        let turkish = Locale(identifier: "tr_TR")
        #expect(KeyCombo.recorded(keyCode: 0x27, modifiers: command, characters: "i", locale: turkish)?.label == "⌘İ")
        #expect(KeyCombo.recorded(keyCode: 0x22, modifiers: command, characters: "ı", locale: turkish)?.label == "⌘I")
        #expect(KeyCombo.recorded(keyCode: 0x29, modifiers: command, characters: "ş", locale: turkish)?.label == "⌘Ş")
    }

    /// A global hotkey without ⌘, ⌃ or ⌥ would swallow ordinary typing in every app.
    @Test func rejectsCombosThatWouldEatTyping() {
        #expect(KeyCombo.recorded(keyCode: 0x00, modifiers: 0, characters: "a") == nil)
        #expect(KeyCombo.recorded(keyCode: 0x00, modifiers: 0x0200, characters: "a") == nil)
        #expect(KeyCombo.recorded(keyCode: 0x31, modifiers: 0x0200, characters: " ") == nil)
    }

    /// Function keys type nothing, so they may stand alone.
    @Test func functionKeysMayStandAlone() {
        #expect(KeyCombo.recorded(keyCode: 0x69, modifiers: 0, characters: "")?.label == "F13")
    }

    /// A key the layout cannot name (dead key, nothing typed) has no label to show in the menu.
    @Test func rejectsKeysWithoutAName() {
        #expect(KeyCombo.recorded(keyCode: 0x00, modifiers: 0x0100, characters: "") == nil)
    }

    @Test func validityFollowsTheSameRule() {
        #expect(KeyCombo.defaultCombo.isValidHotKey)
        #expect(KeyCombo(keyCode: 0x69, modifiers: 0, label: "F13").isValidHotKey)
        #expect(!KeyCombo(keyCode: 0x00, modifiers: 0x0200, label: "⇧A").isValidHotKey)
        #expect(!KeyCombo(keyCode: 0x00, modifiers: 0x0100, label: "").isValidHotKey)
    }
}
