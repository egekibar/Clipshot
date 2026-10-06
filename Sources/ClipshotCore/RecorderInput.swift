import Foundation

/// What one key press in the "Kısayolu Değiştir" window means.
public enum RecorderInput: Equatable, Sendable {
    /// Esc, ⌘W or ⌘Q: the user wants out of the recorder. Recording ⌘W or ⌘Q would take window closing or
    /// quitting away from every app, which nobody pressing them in a small window means to do.
    case cancel
    /// Cannot serve as a global hotkey (it would swallow ordinary typing); the recorder keeps listening.
    case rejected
    case combo(KeyCombo)

    static let vkEscape: UInt32 = 0x35

    public static func interpret(
        keyCode: UInt32, modifiers: UInt32, characters: String, locale: Locale = .current
    ) -> RecorderInput {
        let relevant = modifiers & (KeyCombo.commandKey | KeyCombo.shiftKey | KeyCombo.optionKey | KeyCombo.controlKey)
        if keyCode == vkEscape && relevant == 0 { return .cancel }
        // By character, like AppKit's own key equivalents, so it holds on layouts where W and Q sit elsewhere.
        if relevant == KeyCombo.commandKey && ["w", "q"].contains(characters.lowercased()) { return .cancel }
        let combo = KeyCombo.recorded(keyCode: keyCode, modifiers: relevant, characters: characters, locale: locale)
        return combo.map { .combo($0) } ?? .rejected
    }
}
