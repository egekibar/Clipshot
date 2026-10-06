import CoreGraphics

/// How a marking panel ends.
public enum MarkupEnding: Sendable {
    /// ↩, ⌘C, Kopyala.
    case copy
    /// Clicking anywhere else, or ⌘P while the panel is up.
    case dismiss
    /// Esc, ✕.
    case cancel
}

/// What an ending means. nil leaves the clipboard, or the marks kept in Geçmiş, as they are.
public struct MarkupResult {
    public var clipboard: CGImage?
    public var marks: [Mark]?
}

/// One marking panel: the screenshot, its marks, and what reaches the clipboard and Geçmiş when the panel closes.
public struct MarkupSession {
    public let image: CGImage
    /// Pixels per image point.
    public let scale: CGFloat
    /// A fresh capture: its plain screenshot is already on the clipboard. Reopened from Geçmiş, it is not.
    public let clipboardHasImage: Bool
    public var document: MarkupDocument
    private let savedMarks: [Mark]

    public init(image: CGImage, scale: CGFloat, marks: [Mark] = [], clipboardHasImage: Bool = true) {
        self.image = image
        self.scale = scale
        self.clipboardHasImage = clipboardHasImage
        document = MarkupDocument(marks: marks)
        savedMarks = marks
    }

    /// Esc drops the edits. Otherwise changed marks are kept, and the screenshot is copied: by ↩ always, by clicking
    /// away only right after a capture (its plain version is on the clipboard and the marks belong there). Copying
    /// without marks copies the plain screenshot, unless it is on the clipboard already. A mark still under the mouse
    /// counts.
    public mutating func finish(_ ending: MarkupEnding) -> MarkupResult {
        document.end()
        guard ending != .cancel else { return MarkupResult(clipboard: nil, marks: nil) }
        let marks = document.marks
        let changed = marks == savedMarks ? nil : marks
        guard ending == .copy || clipboardHasImage else { return MarkupResult(clipboard: nil, marks: changed) }
        if marks.isEmpty { return MarkupResult(clipboard: clipboardHasImage ? nil : image, marks: changed) }
        return MarkupResult(clipboard: MarkupRenderer.render(image, marks: marks, scale: scale), marks: changed)
    }
}
