import CoreGraphics

/// Where the marking panel goes. Screen rectangles are AppKit's: points, origin bottom-left.
public enum MarkupGeometry {
    public struct Screen: Sendable {
        public var frame: CGRect
        public var visibleFrame: CGRect
        /// Pixels per point.
        public var scale: CGFloat

        public init(frame: CGRect, visibleFrame: CGRect, scale: CGFloat) {
            self.frame = frame
            self.visibleFrame = visibleFrame
            self.scale = scale
        }
    }

    public struct Placement: Equatable, Sendable {
        /// Where the screenshot is shown, in screen points.
        public var frame: CGRect
        /// The screenshot's own size in points: marks live in this space whatever size it is shown at.
        public var imageSize: CGSize
        /// True when it sits exactly over the region it was taken from.
        public var isInPlace: Bool

        public init(frame: CGRect, imageSize: CGSize, isInPlace: Bool) {
            self.frame = frame
            self.imageSize = imageSize
            self.isInPlace = isInPlace
        }
    }

    /// screencapture snaps a selection to whole pixels, so the dragged rectangle can be a point or two off the image.
    static let selectionTolerance: CGFloat = 3
    /// A centered screenshot takes at most this share of the visible screen.
    static let maximumShare: CGFloat = 0.85
    static let toolbarGap: CGFloat = 8
    static let screenMargin: CGFloat = 8

    /// The rectangle a drag from `a` to `b` covers, whichever way it went.
    public static func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// Exactly over the dragged region when the image matches it, so the selection looks frozen in place; otherwise
    /// (a window capture, no drag seen) centered on the screen and shrunk to fit.
    public static func placement(imagePixels: CGSize, selection: CGRect?, screen: Screen) -> Placement {
        let imageSize = CGSize(width: imagePixels.width / screen.scale, height: imagePixels.height / screen.scale)
        if let selection, abs(selection.width - imageSize.width) <= selectionTolerance,
            abs(selection.height - imageSize.height) <= selectionTolerance
        {
            // The image's own size, hung from the selection's top-left corner (where drags usually start).
            let frame = CGRect(
                x: selection.minX, y: selection.maxY - imageSize.height, width: imageSize.width,
                height: imageSize.height)
            return Placement(frame: frame, imageSize: imageSize, isInPlace: true)
        }
        let visible = screen.visibleFrame
        let factor = min(
            1, visible.width * maximumShare / imageSize.width, visible.height * maximumShare / imageSize.height)
        let size = CGSize(width: (imageSize.width * factor).rounded(), height: (imageSize.height * factor).rounded())
        let origin = CGPoint(
            x: (visible.minX + (visible.width - size.width) / 2).rounded(),
            y: (visible.minY + (visible.height - size.height) / 2).rounded())
        return Placement(frame: CGRect(origin: origin, size: size), imageSize: imageSize, isInPlace: false)
    }

    /// Centered under the canvas when it fits on screen, else above it, else inside along its bottom edge; never
    /// past the screen's sides.
    public static func toolbarOrigin(canvas: CGRect, toolbar: CGSize, visibleFrame: CGRect) -> CGPoint {
        let x = min(
            max(canvas.midX - toolbar.width / 2, visibleFrame.minX + screenMargin),
            visibleFrame.maxX - toolbar.width - screenMargin)
        let below = canvas.minY - toolbarGap - toolbar.height
        if below >= visibleFrame.minY { return CGPoint(x: x, y: below) }
        let above = canvas.maxY + toolbarGap
        if above + toolbar.height <= visibleFrame.maxY { return CGPoint(x: x, y: above) }
        return CGPoint(x: x, y: max(canvas.minY, visibleFrame.minY) + 2 * toolbarGap)
    }

    public struct PanelLayout: Equatable, Sendable {
        /// The panel on screen.
        public var panel: CGRect
        /// Inside the panel: the frame drawn around the screenshot, the screenshot, the toolbar.
        public var border: CGRect
        public var canvas: CGRect
        public var toolbar: CGRect
    }

    /// How far the frame around the screenshot reaches out; drawn outside it, so no pixel of the screenshot moves.
    public static let frameWidth: CGFloat = 3

    /// The panel spans the framed screenshot and the toolbar; the screenshot keeps the placement's exact frame.
    public static func panelLayout(placement: Placement, toolbar: CGSize, visibleFrame: CGRect) -> PanelLayout {
        let canvas = placement.frame
        let border = canvas.insetBy(dx: -frameWidth, dy: -frameWidth)
        let toolbarFrame = CGRect(
            origin: toolbarOrigin(canvas: border, toolbar: toolbar, visibleFrame: visibleFrame), size: toolbar)
        let panel = border.union(toolbarFrame)
        func inPanel(_ rect: CGRect) -> CGRect { rect.offsetBy(dx: -panel.minX, dy: -panel.minY) }
        return PanelLayout(
            panel: panel, border: inPanel(border), canvas: inPanel(canvas), toolbar: inPanel(toolbarFrame))
    }

    /// The two back corners of an arrowhead at `tip`, `length` long and `angle` off the shaft on either side.
    public static func arrowhead(from start: CGPoint, to tip: CGPoint, length: CGFloat, angle: CGFloat)
        -> (left: CGPoint, right: CGPoint)
    {
        let back = atan2(tip.y - start.y, tip.x - start.x) + .pi
        func corner(_ direction: CGFloat) -> CGPoint {
            CGPoint(x: tip.x + length * cos(direction), y: tip.y + length * sin(direction))
        }
        return (corner(back + angle), corner(back - angle))
    }
}
