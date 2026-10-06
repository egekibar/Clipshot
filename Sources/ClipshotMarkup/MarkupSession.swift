import CoreGraphics

/// One marking panel: the screenshot, its marks, and what reaches the clipboard when the panel closes.
public struct MarkupSession {
    public let image: CGImage
    /// Pixels per image point.
    public let scale: CGFloat
    public var document = MarkupDocument()

    public init(image: CGImage, scale: CGFloat) {
        self.image = image
        self.scale = scale
    }

    /// The marked screenshot for the clipboard, or nil when it stays as it is: no marks, or Esc (`keepingMarks`
    /// false). A mark still under the mouse counts.
    public mutating func finish(keepingMarks: Bool) -> CGImage? {
        document.end()
        guard keepingMarks, !document.marks.isEmpty else { return nil }
        return MarkupRenderer.render(image, marks: document.marks, scale: scale)
    }
}
