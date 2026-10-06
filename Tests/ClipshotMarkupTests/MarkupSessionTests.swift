import ClipshotTestSupport
import CoreGraphics
import Foundation
import Testing

@testable import ClipshotMarkup

@Suite("MarkupSession")
struct MarkupSessionTests {
    let saved = Mark(tool: .box, color: .blue, points: [CGPoint(x: 60, y: 10), CGPoint(x: 100, y: 50)])

    /// Right after a capture the plain screenshot is already on the clipboard.
    func fresh() -> MarkupSession {
        MarkupSession(image: solidImage(width: 120, height: 80, gray: 1), scale: 2)
    }

    /// Opened from Geçmiş: the clipboard holds something else, and the item may come with marks.
    func fromHistory(marks: [Mark] = []) -> MarkupSession {
        MarkupSession(
            image: solidImage(width: 120, height: 80, gray: 1), scale: 2, marks: marks, clipboardHasImage: false)
    }

    func drawRedBox(_ session: inout MarkupSession) {
        session.document.begin(at: CGPoint(x: 5, y: 5))
        session.document.drag(to: CGPoint(x: 40, y: 30))
        session.document.end()
    }

    // MARK: - Right after a capture

    /// Nothing drawn: the plain screenshot stays on the clipboard and Geçmiş keeps it as it is.
    @Test func withoutMarksNothingIsReplaced() {
        var session = fresh()
        let result = session.finish(.copy)
        #expect(result.clipboard == nil)
        #expect(result.marks == nil)
    }

    @Test func copyPutsTheMarkedScreenshotOnTheClipboardAndKeepsTheMarks() throws {
        var session = fresh()
        drawRedBox(&session)
        let result = session.finish(.copy)
        let image = try #require(result.clipboard)
        #expect(image.width == 120 && image.height == 80)
        #expect(isRed(pixel(image, x: 10, y: 30)))
        #expect(result.marks?.count == 1)
    }

    /// Clicking away is "done": the marks are kept and copied.
    @Test func clickingAwayKeepsAndCopiesTheMarks() {
        var session = fresh()
        drawRedBox(&session)
        let result = session.finish(.dismiss)
        #expect(result.clipboard != nil)
        #expect(result.marks?.count == 1)
    }

    /// Esc drops the marks: the plain screenshot stays on the clipboard and in Geçmiş.
    @Test func cancellingDropsTheMarks() {
        var session = fresh()
        drawRedBox(&session)
        let result = session.finish(.cancel)
        #expect(result.clipboard == nil)
        #expect(result.marks == nil)
    }

    /// ↩ pressed with the mouse still down keeps the mark being drawn.
    @Test func aMarkStillBeingDrawnIsKept() throws {
        var session = fresh()
        session.document.begin(at: CGPoint(x: 5, y: 5))
        session.document.drag(to: CGPoint(x: 40, y: 30))
        let result = session.finish(.copy)
        let image = try #require(result.clipboard)
        #expect(isRed(pixel(image, x: 10, y: 30)))
    }

    // MARK: - Opened from Geçmiş

    /// Kopyala on an unmarked item copies the screenshot itself.
    @Test func copyingAnUnmarkedItemCopiesThePlainScreenshot() throws {
        var session = fromHistory()
        let result = session.finish(.copy)
        let image = try #require(result.clipboard)
        #expect(image.width == 120 && image.height == 80)
        #expect(isWhite(pixel(image, x: 10, y: 30)))
        #expect(result.marks == nil)
    }

    @Test func anItemOpensWithItsMarksAndCopiesThem() throws {
        var session = fromHistory(marks: [saved])
        #expect(session.document.marks == [saved])
        let result = session.finish(.copy)
        let image = try #require(result.clipboard)
        #expect(pixel(image, x: 120, y: 40).b > 0.8)  // the saved blue box's left edge, 60 pt = 120 px
    }

    /// Clicking away from an item never touches the clipboard; what was drawn is kept for next time.
    @Test func clickingAwayFromAnItemKeepsTheEditsOnly() {
        var session = fromHistory(marks: [saved])
        drawRedBox(&session)
        let result = session.finish(.dismiss)
        #expect(result.clipboard == nil)
        #expect(result.marks?.count == 2)
    }

    /// Undoing a saved mark is an edit too.
    @Test func undoingASavedMarkIsKept() {
        var session = fromHistory(marks: [saved])
        session.document.undo()
        let result = session.finish(.dismiss)
        #expect(result.marks == [])
    }

    @Test func cancellingLeavesAnItemAsItWas() {
        var session = fromHistory(marks: [saved])
        drawRedBox(&session)
        let result = session.finish(.cancel)
        #expect(result.clipboard == nil)
        #expect(result.marks == nil)
    }
}

@Suite("Mark persistence")
struct MarkPersistenceTests {
    /// Geçmiş stores marks as JSON next to the screenshot.
    @Test func marksSurviveAJSONRoundTrip() throws {
        let marks = [
            Mark(tool: .arrow, color: .blue, points: [CGPoint(x: 1.5, y: 2), CGPoint(x: 30, y: 40)]),
            Mark(tool: .pen, color: .black, points: [.zero, CGPoint(x: 3, y: 4), CGPoint(x: 9, y: 1)]),
        ]
        let data = try JSONEncoder().encode(marks)
        #expect(try JSONDecoder().decode([Mark].self, from: data) == marks)
    }

    @Test func reopenedMarksCanBeUndone() {
        let first = Mark(tool: .box, color: .red, points: [.zero, CGPoint(x: 10, y: 10)])
        let second = Mark(tool: .arrow, color: .red, points: [.zero, CGPoint(x: 20, y: 0)])
        var document = MarkupDocument(marks: [first, second])
        document.undo()
        #expect(document.marks == [first])
    }
}
