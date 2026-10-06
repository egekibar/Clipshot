/// What a key press does while the marking panel is up.
public enum MarkupAction: Equatable, Sendable {
    case tool(MarkTool)
    case undo
    /// Put the marked screenshot on the clipboard and close.
    case copy
    /// Close and drop the marks; the plain screenshot stays on the clipboard.
    case cancel
}

public enum MarkupKeys {
    /// `characters` without modifiers (`charactersIgnoringModifiers`); letters by character, like AppKit's own
    /// key equivalents, so they hold on every layout.
    public static func action(keyCode: UInt16, characters: String, command: Bool) -> MarkupAction? {
        switch keyCode {
        case 0x35: return .cancel  // esc
        case 0x24, 0x4C: return command ? nil : .copy  // return, keypad enter
        case 0x33: return command ? nil : .undo  // delete
        default: break
        }
        let key = characters.lowercased()
        if command {
            switch key {
            case "z": return .undo
            case "c": return .copy
            default: return nil
            }
        }
        switch key {
        case "1": return .tool(.box)
        case "2": return .tool(.arrow)
        case "3": return .tool(.highlighter)
        case "4": return .tool(.pen)
        default: return nil
        }
    }
}
