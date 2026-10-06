import CoreGraphics
import Testing

@testable import ClipshotMarkup

@Suite("MarkupSession")
struct MarkupSessionTests {
    func session() -> MarkupSession {
        MarkupSession(image: solidImage(width: 120, height: 80, gray: 1), scale: 2)
    }

    /// Nothing drawn: the plain screenshot is already on the clipboard and stays there.
    @Test func withoutMarksNothingIsReplaced() {
        var session = session()
        let result = session.finish(keepingMarks: true)
        #expect(result == nil)
    }

    @Test func marksGiveTheMarkedScreenshotAtFullSize() throws {
        var session = session()
        session.document.begin(at: CGPoint(x: 5, y: 5))
        session.document.drag(to: CGPoint(x: 40, y: 30))
        session.document.end()
        let result = session.finish(keepingMarks: true)
        let image = try #require(result)
        #expect(image.width == 120 && image.height == 80)
        #expect(isRed(pixel(image, x: 10, y: 30)))
    }

    /// Esc drops the marks.
    @Test func cancellingDropsTheMarks() {
        var session = session()
        session.document.begin(at: CGPoint(x: 5, y: 5))
        session.document.drag(to: CGPoint(x: 40, y: 30))
        session.document.end()
        let result = session.finish(keepingMarks: false)
        #expect(result == nil)
    }

    /// ↩ pressed with the mouse still down keeps the mark being drawn.
    @Test func aMarkStillBeingDrawnIsKept() throws {
        var session = session()
        session.document.begin(at: CGPoint(x: 5, y: 5))
        session.document.drag(to: CGPoint(x: 40, y: 30))
        let result = session.finish(keepingMarks: true)
        let image = try #require(result)
        #expect(isRed(pixel(image, x: 10, y: 30)))
    }
}
