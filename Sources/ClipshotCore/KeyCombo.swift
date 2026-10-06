import Foundation

/// Global hotkey definition using Carbon virtual key codes and modifier masks
/// (values copied from HIToolbox/Events.h so Core stays framework-free).
public struct KeyCombo: Hashable, Sendable, Codable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var label: String

    public init(keyCode: UInt32, modifiers: UInt32, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    public static let commandKey: UInt32 = 1 << 8
    public static let shiftKey: UInt32 = 1 << 9
    public static let optionKey: UInt32 = 1 << 11
    public static let controlKey: UInt32 = 1 << 12

    static let vkANSIP: UInt32 = 0x23
    static let vkSpace: UInt32 = 0x31

    /// ⌘P. It takes over Print in every app while Clipshot holds it, which is why the menu can pause it.
    public static let defaultCombo = KeyCombo(keyCode: vkANSIP, modifiers: commandKey, label: "⌘P")

    /// Carbon modifier mask from the four modifier states (the recorder reads them off an `NSEvent`).
    public static func modifierMask(command: Bool, shift: Bool, option: Bool, control: Bool) -> UInt32 {
        (command ? commandKey : 0) | (shift ? shiftKey : 0) | (option ? optionKey : 0) | (control ? controlKey : 0)
    }

    /// Builds a combo from a recorded key press, or nil when it cannot serve as a global hotkey.
    ///
    /// `characters` is what the current keyboard layout types for the key without modifiers, so a Turkish-Q
    /// letter is labelled as printed on the keycap; `locale` decides its capital (i → İ, ı → I in Turkish).
    /// Keys that type nothing visible are named by key code.
    public static func recorded(
        keyCode: UInt32, modifiers: UInt32, characters: String, locale: Locale = .current
    ) -> KeyCombo? {
        let relevant = modifiers & (commandKey | shiftKey | optionKey | controlKey)
        guard let name = keyName(keyCode: keyCode, characters: characters, locale: locale) else { return nil }
        let combo = KeyCombo(keyCode: keyCode, modifiers: relevant, label: modifierGlyphs(relevant) + name)
        return combo.isValidHotKey ? combo : nil
    }

    /// A global hotkey needs ⌘, ⌃ or ⌥ (Shift alone would swallow ordinary typing in every app);
    /// function keys are the exception, since they type nothing.
    public var isValidHotKey: Bool {
        guard !label.isEmpty else { return false }
        return modifiers & (Self.commandKey | Self.optionKey | Self.controlKey) != 0
            || Self.functionKeys[keyCode] != nil
    }

    /// Apple's menu order: ⌃ ⌥ ⇧ ⌘.
    static func modifierGlyphs(_ modifiers: UInt32) -> String {
        var glyphs = ""
        if modifiers & controlKey != 0 { glyphs += "⌃" }
        if modifiers & optionKey != 0 { glyphs += "⌥" }
        if modifiers & shiftKey != 0 { glyphs += "⇧" }
        if modifiers & commandKey != 0 { glyphs += "⌘" }
        return glyphs
    }

    static func keyName(keyCode: UInt32, characters: String, locale: Locale) -> String? {
        if let name = functionKeys[keyCode] ?? specialKeys[keyCode] { return name }
        let visible = characters.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        guard !visible.isEmpty else { return nil }
        return visible.uppercased(with: locale)
    }

    /// kVK_F1…kVK_F20 from HIToolbox/Events.h.
    static let functionKeys: [UInt32: String] = [
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
        0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12", 0x69: "F13", 0x6B: "F14", 0x71: "F15",
        0x6A: "F16", 0x40: "F17", 0x4F: "F18", 0x50: "F19", 0x5A: "F20",
    ]

    /// Keys whose character is invisible or ambiguous, named the way macOS menus show them.
    static let specialKeys: [UInt32: String] = [
        vkSpace: "Space", 0x24: "↩", 0x4C: "⌤", 0x30: "⇥", 0x33: "⌫", 0x75: "⌦", 0x35: "⎋",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
        0x73: "↖", 0x77: "↘", 0x74: "⇞", 0x79: "⇟",
    ]
}
