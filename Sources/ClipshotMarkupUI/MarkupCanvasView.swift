import AppKit
import ClipshotMarkup

/// The frozen screenshot and its marks. Its bounds are the screenshot's own points with the origin top-left, whatever
/// size it is shown at, so mouse positions and marks share one coordinate space.
final class MarkupCanvasView: NSView {
    var session: MarkupSession {
        didSet { needsDisplay = true }
    }
    /// After every finished mark, so the toolbar can follow (undo becomes available).
    var onChange: () -> Void = {}

    init(session: MarkupSession, imageSize: CGSize, displaySize: CGSize) {
        self.session = session
        super.init(frame: CGRect(origin: .zero, size: displaySize))
        bounds = CGRect(origin: .zero, size: imageSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }

    /// The first click already draws, even before the panel is key.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        // CGContext draws images bottom-up; this view is top-down.
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high
        context.draw(session.image, in: CGRect(origin: .zero, size: bounds.size))
        context.restoreGState()
        MarkDrawing.draw(session.document.marks, in: context)
        if let current = session.document.current { MarkDrawing.draw(current, in: context) }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        session.document.begin(at: imagePoint(event))
    }

    override func mouseDragged(with event: NSEvent) {
        session.document.drag(to: imagePoint(event))
    }

    override func mouseUp(with event: NSEvent) {
        session.document.drag(to: imagePoint(event))
        session.document.end()
        onChange()
    }

    /// The mouse in image points, kept on the screenshot when a drag runs past its edge.
    private func imagePoint(_ event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        return CGPoint(x: min(max(point.x, 0), bounds.width), y: min(max(point.y, 0), bounds.height))
    }
}

/// The thin accent-colored frame that marks the frozen region as editable. It lies outside the screenshot.
final class MarkupFrameView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let inset = MarkupGeometry.frameWidth / 2
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: 4, yRadius: 4)
        path.lineWidth = 2
        NSColor.controlAccentColor.setStroke()
        path.stroke()
    }
}
