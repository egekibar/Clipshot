import Foundation
import Testing

@testable import ClipshotCore

@Suite("RecorderInput")
struct RecorderInputTests {
    let command: UInt32 = 0x0100
    let shift: UInt32 = 0x0200
    let control: UInt32 = 0x1000

    @Test func escapeAloneCancels() {
        #expect(RecorderInput.interpret(keyCode: 0x35, modifiers: 0, characters: "\u{1B}") == .cancel)
    }

    /// Esc with a modifier is an ordinary combo and can be recorded.
    @Test func controlEscapeIsRecorded() {
        let want = KeyCombo(keyCode: 0x35, modifiers: control, label: "⌃⎋")
        #expect(RecorderInput.interpret(keyCode: 0x35, modifiers: control, characters: "\u{1B}") == .combo(want))
    }

    /// ⌘W and ⌘Q pressed in the recorder mean "close this", never "take ⌘W away from every app".
    /// Matched by character, so it holds on layouts where W and Q sit on other keys.
    @Test func commandWAndCommandQCancel() {
        #expect(RecorderInput.interpret(keyCode: 0x0D, modifiers: command, characters: "w") == .cancel)
        #expect(RecorderInput.interpret(keyCode: 0x0C, modifiers: command, characters: "q") == .cancel)
        // Turkish-F: the key that types "w" is where US has "]".
        #expect(RecorderInput.interpret(keyCode: 0x1E, modifiers: command, characters: "w") == .cancel)
    }

    @Test func commandShiftWIsRecorded() {
        let want = KeyCombo(keyCode: 0x0D, modifiers: command | shift, label: "⇧⌘W")
        #expect(RecorderInput.interpret(keyCode: 0x0D, modifiers: command | shift, characters: "w") == .combo(want))
    }

    /// ⌘C, ⌘V, ⌘X, ⌘Z and ⌘A belong to every app; taking ⌘V would even block pasting the screenshot.
    /// Matched by character, like ⌘W and ⌘Q.
    @Test func editingShortcutsAreReserved() {
        #expect(RecorderInput.interpret(keyCode: 0x08, modifiers: command, characters: "c") == .reserved("⌘C"))
        #expect(RecorderInput.interpret(keyCode: 0x09, modifiers: command, characters: "v") == .reserved("⌘V"))
        #expect(RecorderInput.interpret(keyCode: 0x07, modifiers: command, characters: "x") == .reserved("⌘X"))
        #expect(RecorderInput.interpret(keyCode: 0x06, modifiers: command, characters: "z") == .reserved("⌘Z"))
        #expect(RecorderInput.interpret(keyCode: 0x00, modifiers: command, characters: "a") == .reserved("⌘A"))
    }

    @Test func editingKeysWithMoreModifiersAreRecorded() {
        let want = KeyCombo(keyCode: 0x09, modifiers: command | shift, label: "⇧⌘V")
        #expect(RecorderInput.interpret(keyCode: 0x09, modifiers: command | shift, characters: "v") == .combo(want))
    }

    @Test func commandPIsTheDefault() {
        #expect(RecorderInput.interpret(keyCode: 0x23, modifiers: command, characters: "p") == .combo(.defaultCombo))
    }

    @Test func bareLetterIsRejected() {
        #expect(RecorderInput.interpret(keyCode: 0x00, modifiers: 0, characters: "a") == .rejected)
    }
}
