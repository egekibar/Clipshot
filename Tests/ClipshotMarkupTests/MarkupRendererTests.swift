import ClipshotTestSupport
import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import ClipshotMarkup

@Suite("MarkupRenderer")
struct MarkupRendererTests {
    func mark(_ tool: MarkTool, _ color: MarkColor, _ points: [(CGFloat, CGFloat)]) -> Mark {
        Mark(tool: tool, color: color, points: points.map { CGPoint(x: $0.0, y: $0.1) })
    }

    /// What reaches the clipboard keeps the screenshot's full (Retina) resolution.
    @Test func keepsTheScreenshotsPixelSize() throws {
        let image = solidImage(width: 80, height: 60, gray: 1)
        let rendered = try #require(MarkupRenderer.render(image, marks: [], scale: 2))
        #expect(rendered.width == 80 && rendered.height == 60)
    }

    @Test func boxOutlinesItsRectangleAndLeavesTheInsideAlone() throws {
        let image = solidImage(width: 100, height: 100, gray: 1)
        let rendered = try #require(
            MarkupRenderer.render(image, marks: [mark(.box, .red, [(20, 20), (80, 80)])], scale: 1))
        #expect(isRed(pixel(rendered, x: 20, y: 50)))
        #expect(isWhite(pixel(rendered, x: 50, y: 50)))
    }

    /// Marks are in image points with the origin top-left; on a Retina image every point is two pixels.
    @Test func marksAreTopLeftPointsScaledToPixels() throws {
        let image = solidImage(width: 200, height: 200, gray: 1)
        let rendered = try #require(
            MarkupRenderer.render(image, marks: [mark(.box, .red, [(10, 10), (40, 30)])], scale: 2))
        #expect(isRed(pixel(rendered, x: 20, y: 40)))  // left edge, 10 pt = 20 px from the left
        #expect(isRed(pixel(rendered, x: 50, y: 20)))  // top edge, 10 pt = 20 px from the top
        #expect(isWhite(pixel(rendered, x: 50, y: 180)))  // the bottom half stays untouched
    }

    @Test func arrowReachesItsTip() throws {
        let image = solidImage(width: 100, height: 100, gray: 1)
        let rendered = try #require(
            MarkupRenderer.render(image, marks: [mark(.arrow, .red, [(10, 50), (90, 50)])], scale: 1))
        #expect(isRed(pixel(rendered, x: 50, y: 50)))
        #expect(isRed(pixel(rendered, x: 86, y: 50)))
        #expect(isWhite(pixel(rendered, x: 50, y: 20)))
    }

    /// The highlighter tints what is under it and keeps it readable: white turns yellow, black stays dark.
    @Test func highlighterTintsWithoutHiding() throws {
        let marks = [mark(.highlighter, .yellow, [(10, 10), (90, 90)])]
        let onWhite = try #require(
            MarkupRenderer.render(solidImage(width: 100, height: 100, gray: 1), marks: marks, scale: 1))
        let white = pixel(onWhite, x: 50, y: 50)
        #expect(white.r > 0.95 && white.g > 0.85 && white.b < 0.8)
        let onBlack = try #require(
            MarkupRenderer.render(solidImage(width: 100, height: 100, gray: 0), marks: marks, scale: 1))
        #expect(pixel(onBlack, x: 50, y: 50).r < 0.6)
    }

    /// Mouse samples are dense; the pen smooths between them, so straight runs stay straight.
    @Test func penFollowsItsPath() throws {
        let image = solidImage(width: 100, height: 100, gray: 1)
        let path: [(CGFloat, CGFloat)] = [(10, 10), (30, 10), (50, 10), (50, 35), (50, 60)]
        let rendered = try #require(MarkupRenderer.render(image, marks: [mark(.pen, .red, path)], scale: 1))
        #expect(isRed(pixel(rendered, x: 30, y: 10)))
        #expect(isRed(pixel(rendered, x: 50, y: 40)))
        #expect(isWhite(pixel(rendered, x: 20, y: 50)))
    }

    @Test func pngKeepsTheSize() throws {
        let rendered = try #require(
            MarkupRenderer.render(solidImage(width: 64, height: 32, gray: 1), marks: [], scale: 2))
        let data = try #require(MarkupRenderer.pngData(rendered))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 64 && decoded.height == 32)
    }
}
