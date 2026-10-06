import Foundation

/// What one key press in the "Kısayolu Değiştir" window means.
public enum RecorderInput: Equatable, Sendable {
    /// Esc, ⌘W or ⌘Q: the user wants out of the recorder. Recording ⌘W or ⌘Q would take window closing or
    /// quitting away from every app, which nobody pressing them in a small window means to do.
    case cancel
    /// Cannot serve as a global hotkey (it would swallow ordinary typing); the recorder keeps listening.
    case rejected
    /// An editing shortcut every app needs (the label, "⌘V"); the recorder keeps listening.
    case reserved(String)
    case combo(KeyCombo)

    static let vkEscape: UInt32 = 0x35
    /// ⌘C ⌘V ⌘X ⌘Z ⌘A, by character.
    static let editingKeys: Set<String> = ["c", "v", "x", "z", "a"]

    public static func interpret(
        keyCode: UInt32, modifiers: UInt32, characters: String, locale: Locale = .current
    ) -> RecorderInput {
        let relevant = modifiers & (KeyCombo.commandKey | KeyCombo.shiftKey | KeyCombo.optionKey | KeyCombo.controlKey)
        if keyCode == vkEscape && relevant == 0 { return .cancel }
        // By character, like AppKit's own key equivalents, so it holds on layouts where W and Q sit elsewhere.
        if relevant == KeyCombo.commandKey && ["w", "q"].contains(characters.lowercased()) { return .cancel }
        guard
            let combo = KeyCombo.recorded(
                keyCode: keyCode, modifiers: relevant, characters: characters, locale: locale)
        else { return .rejected }
        if relevant == KeyCombo.commandKey && editingKeys.contains(characters.lowercased()) {
            return .reserved(combo.label)
        }
        return .combo(combo)
    }
}
