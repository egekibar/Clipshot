import CoreGraphics
import Testing

@testable import ClipshotMarkup

@Suite("MarkupDocument")
struct MarkupDocumentTests {
    func draw(_ document: inout MarkupDocument, _ points: [(CGFloat, CGFloat)]) {
        document.begin(at: CGPoint(x: points[0].0, y: points[0].1))
        for point in points.dropFirst() { document.drag(to: CGPoint(x: point.0, y: point.1)) }
        document.end()
    }

    /// "Mark a spot" is the job: the panel opens ready to drag a red box.
    @Test func opensWithARedBox() {
        let document = MarkupDocument()
        #expect(document.tool == .box)
        #expect(document.color == .red)
        #expect(document.marks.isEmpty)
    }

    @Test func dragDrawsABox() {
        var document = MarkupDocument()
        draw(&document, [(10, 10), (30, 20), (60, 40)])
        #expect(
            document.marks == [Mark(tool: .box, color: .red, points: [CGPoint(x: 10, y: 10), CGPoint(x: 60, y: 40)])])
    }

    /// A click, or a twitch of the hand while clicking, is not a mark.
    @Test func clickWithoutADragAddsNothing() {
        var document = MarkupDocument()
        draw(&document, [(10, 10), (11, 12)])
        #expect(document.marks.isEmpty)
    }

    /// A perfectly horizontal arrow has no height and still counts.
    @Test func straightArrowCounts() {
        var document = MarkupDocument()
        document.tool = .arrow
        draw(&document, [(0, 50), (80, 50)])
        #expect(document.marks.count == 1)
        #expect(document.marks.first?.tool == .arrow)
    }

    @Test func penKeepsItsWholePath() {
        var document = MarkupDocument()
        document.tool = .pen
        draw(&document, [(0, 0), (5, 0), (5, 5), (10, 5)])
        #expect(
            document.marks.first?.points == [
                CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 0), CGPoint(x: 5, y: 5), CGPoint(x: 10, y: 5),
            ])
    }

    /// The canvas shows the mark under the mouse before it is committed.
    @Test func markInProgressIsVisibleUntilReleased() {
        var document = MarkupDocument()
        document.begin(at: CGPoint(x: 0, y: 0))
        document.drag(to: CGPoint(x: 40, y: 30))
        #expect(document.current == Mark(tool: .box, color: .red, points: [.zero, CGPoint(x: 40, y: 30)]))
        document.end()
        #expect(document.current == nil)
    }

    @Test func undoTakesBackTheLastMark() {
        var document = MarkupDocument()
        draw(&document, [(0, 0), (20, 20)])
        draw(&document, [(30, 30), (60, 60)])
        document.undo()
        #expect(document.marks.count == 1)
        #expect(document.marks.first?.points.first == .zero)
        document.undo()
        document.undo()
        #expect(document.marks.isEmpty)
    }

    /// The highlighter starts yellow, the others red; a color picked for one tool stays with that tool.
    @Test func eachToolKeepsItsOwnColor() {
        var document = MarkupDocument()
        document.tool = .highlighter
        #expect(document.color == .yellow)
        document.tool = .box
        document.color = .blue
        document.tool = .arrow
        #expect(document.color == .red)
        document.tool = .box
        #expect(document.color == .blue)
    }

    @Test func aMarkKeepsTheColorItWasDrawnIn() {
        var document = MarkupDocument()
        draw(&document, [(0, 0), (20, 20)])
        document.color = .green
        #expect(document.marks.first?.color == .red)
    }
}
