import CoreGraphics
import Testing

@testable import ClipshotMarkup

@Suite("MarkupGeometry")
struct MarkupGeometryTests {
    let retina = MarkupGeometry.Screen(
        frame: CGRect(x: 0, y: 0, width: 1000, height: 800), visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
        scale: 2)

    @Test func dragCoversTheSameRectInEveryDirection() {
        let want = CGRect(x: 10, y: 20, width: 100, height: 50)
        #expect(MarkupGeometry.rect(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 110, y: 70)) == want)
        #expect(MarkupGeometry.rect(from: CGPoint(x: 110, y: 70), to: CGPoint(x: 10, y: 20)) == want)
        #expect(MarkupGeometry.rect(from: CGPoint(x: 110, y: 20), to: CGPoint(x: 10, y: 70)) == want)
    }

    /// The selection freezes in place: the canvas covers exactly the region the user dragged out.
    @Test func sitsOverTheSelectionWhenTheImageMatchesIt() {
        let selection = CGRect(x: 300, y: 400, width: 100, height: 50)
        let placement = MarkupGeometry.placement(
            imagePixels: CGSize(width: 200, height: 100), selection: selection, screen: retina)
        #expect(placement.frame == selection)
        #expect(placement.imageSize == CGSize(width: 100, height: 50))
        #expect(placement.isInPlace)
    }

    /// screencapture snaps to whole pixels, so the image may be a point off the dragged rectangle; the canvas takes
    /// the image's size and keeps the selection's top-left corner (where most drags start).
    @Test func toleratesTheRoundingOfASelection() {
        let selection = CGRect(x: 300.5, y: 400, width: 101, height: 49)
        let placement = MarkupGeometry.placement(
            imagePixels: CGSize(width: 200, height: 100), selection: selection, screen: retina)
        #expect(placement.isInPlace)
        #expect(placement.frame == CGRect(x: 300.5, y: 399, width: 100, height: 50))
    }

    /// Window captures (Space) and odd selections give no usable rectangle: the canvas is centered instead.
    @Test func centersWhenTheSelectionDoesNotMatch() {
        let placement = MarkupGeometry.placement(
            imagePixels: CGSize(width: 200, height: 100), selection: CGRect(x: 0, y: 0, width: 300, height: 300),
            screen: retina)
        #expect(!placement.isInPlace)
        #expect(placement.frame == CGRect(x: 450, y: 375, width: 100, height: 50))
    }

    @Test func centersWithoutASelection() {
        let placement = MarkupGeometry.placement(
            imagePixels: CGSize(width: 200, height: 100), selection: nil, screen: retina)
        #expect(placement.frame == CGRect(x: 450, y: 375, width: 100, height: 50))
    }

    /// A centered image larger than the screen is shown smaller, keeping its aspect; marks still use image points.
    @Test func shrinksABigImageToFit() {
        let screen = MarkupGeometry.Screen(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), scale: 2)
        let placement = MarkupGeometry.placement(
            imagePixels: CGSize(width: 4000, height: 2000), selection: nil, screen: screen)
        #expect(placement.imageSize == CGSize(width: 2000, height: 1000))
        #expect(placement.frame == CGRect(x: 108, y: 144, width: 1224, height: 612))
    }

    @Test func toolbarGoesBelowTheCanvasWhenThereIsRoom() {
        let origin = MarkupGeometry.toolbarOrigin(
            canvas: CGRect(x: 100, y: 300, width: 400, height: 200), toolbar: CGSize(width: 300, height: 36),
            visibleFrame: retina.visibleFrame)
        #expect(origin == CGPoint(x: 150, y: 256))
    }

    @Test func toolbarGoesAboveWhenTheCanvasTouchesTheBottom() {
        let origin = MarkupGeometry.toolbarOrigin(
            canvas: CGRect(x: 100, y: 20, width: 400, height: 200), toolbar: CGSize(width: 300, height: 36),
            visibleFrame: retina.visibleFrame)
        #expect(origin == CGPoint(x: 150, y: 228))
    }

    @Test func toolbarStaysOnScreenBesideANarrowCanvasAtTheEdge() {
        let origin = MarkupGeometry.toolbarOrigin(
            canvas: CGRect(x: 0, y: 300, width: 100, height: 100), toolbar: CGSize(width: 300, height: 36),
            visibleFrame: retina.visibleFrame)
        #expect(origin == CGPoint(x: 8, y: 256))
    }

    /// A canvas that fills the screen leaves no room outside it; the toolbar floats inside along its bottom edge.
    @Test func toolbarGoesInsideWhenTheCanvasFillsTheScreen() {
        let origin = MarkupGeometry.toolbarOrigin(
            canvas: CGRect(x: 0, y: 0, width: 1000, height: 800), toolbar: CGSize(width: 300, height: 36),
            visibleFrame: retina.visibleFrame)
        #expect(origin == CGPoint(x: 350, y: 16))
    }

    /// One panel holds the frame, the screenshot and the toolbar. The screenshot must not move by a single point:
    /// the frame is drawn outside it, and every subview is placed relative to the panel's origin.
    @Test func panelLayoutKeepsTheScreenshotExactlyInPlace() {
        let placement = MarkupGeometry.Placement(
            frame: CGRect(x: 100, y: 300, width: 400, height: 200), imageSize: CGSize(width: 400, height: 200),
            isInPlace: true)
        let layout = MarkupGeometry.panelLayout(
            placement: placement, toolbar: CGSize(width: 300, height: 36), visibleFrame: retina.visibleFrame)
        #expect(layout.canvas.offsetBy(dx: layout.panel.minX, dy: layout.panel.minY) == placement.frame)
        #expect(layout.border == layout.canvas.insetBy(dx: -3, dy: -3))
        // Below the frame, centered: y = 300 - 3 - 8 - 36.
        #expect(layout.toolbar.offsetBy(dx: layout.panel.minX, dy: layout.panel.minY).origin == CGPoint(x: 150, y: 253))
        #expect(layout.panel == CGRect(x: 97, y: 253, width: 406, height: 250))
    }

    /// The arrowhead's two wings point back along the shaft, `length` long, `angle` off it.
    @Test func arrowheadWingsPointBackAlongTheShaft() {
        let (left, right) = MarkupGeometry.arrowhead(
            from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0), length: 12, angle: .pi / 6)
        #expect(abs(left.x - 89.6077) < 0.001 && abs(left.y + 6) < 0.001)
        #expect(abs(right.x - 89.6077) < 0.001 && abs(right.y - 6) < 0.001)
    }
}
