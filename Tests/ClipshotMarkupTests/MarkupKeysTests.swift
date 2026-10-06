import Testing

@testable import ClipshotMarkup

@Suite("MarkupKeys")
struct MarkupKeysTests {
    @Test func digitsPickTheToolsInToolbarOrder() {
        #expect(MarkupKeys.action(keyCode: 0x12, characters: "1", command: false) == .tool(.box))
        #expect(MarkupKeys.action(keyCode: 0x13, characters: "2", command: false) == .tool(.arrow))
        #expect(MarkupKeys.action(keyCode: 0x14, characters: "3", command: false) == .tool(.highlighter))
        #expect(MarkupKeys.action(keyCode: 0x15, characters: "4", command: false) == .tool(.pen))
    }

    /// ↩ and ⌘C put the marked image on the clipboard; on the keypad ⌤ does too.
    @Test func returnAndCommandCCopy() {
        #expect(MarkupKeys.action(keyCode: 0x24, characters: "\r", command: false) == .copy)
        #expect(MarkupKeys.action(keyCode: 0x4C, characters: "\u{3}", command: false) == .copy)
        #expect(MarkupKeys.action(keyCode: 0x08, characters: "c", command: true) == .copy)
    }

    @Test func commandZAndDeleteUndo() {
        #expect(MarkupKeys.action(keyCode: 0x06, characters: "z", command: true) == .undo)
        #expect(MarkupKeys.action(keyCode: 0x33, characters: "\u{7F}", command: false) == .undo)
    }

    @Test func escapeCancels() {
        #expect(MarkupKeys.action(keyCode: 0x35, characters: "\u{1B}", command: false) == .cancel)
    }

    /// Other keys do nothing, and a digit with ⌘ belongs to whatever else wants it.
    @Test func otherKeysAreIgnored() {
        #expect(MarkupKeys.action(keyCode: 0x00, characters: "a", command: false) == nil)
        #expect(MarkupKeys.action(keyCode: 0x12, characters: "1", command: true) == nil)
        #expect(MarkupKeys.action(keyCode: 0x08, characters: "c", command: false) == nil)
    }
}
