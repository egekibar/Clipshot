import CoreGraphics

/// The marks on one screenshot, the mark being drawn, the current tool and each tool's color.
public struct MarkupDocument: Sendable {
    /// Shorter drags are a click or a twitch of the hand, not a mark.
    static let minimumDrag: CGFloat = 3

    public private(set) var marks: [Mark] = []
    /// The mark under the mouse, shown live and committed on release.
    public private(set) var current: Mark?
    /// "Mark a spot" is the job, so the panel opens ready to drag a box.
    public var tool: MarkTool = .box
    private var colors: [MarkTool: MarkColor] = [.box: .red, .arrow: .red, .highlighter: .yellow, .pen: .red]

    /// `marks`: those saved with a screenshot reopened from Geçmiş; they can be undone like new ones.
    public init(marks: [Mark] = []) {
        self.marks = marks
    }

    /// The current tool's color; picking one changes that tool only.
    public var color: MarkColor {
        get { colors[tool] ?? .red }
        set { colors[tool] = newValue }
    }

    public mutating func begin(at point: CGPoint) {
        current = Mark(tool: tool, color: color, points: [point])
    }

    public mutating func drag(to point: CGPoint) {
        guard var mark = current, let start = mark.points.first else { return }
        mark.points = mark.tool == .pen ? mark.points + [point] : [start, point]
        current = mark
    }

    public mutating func end() {
        defer { current = nil }
        guard let mark = current, Self.reachesFarEnough(mark) else { return }
        marks.append(mark)
    }

    public mutating func undo() {
        if !marks.isEmpty { marks.removeLast() }
    }

    static func reachesFarEnough(_ mark: Mark) -> Bool {
        guard let start = mark.points.first else { return false }
        return mark.points.contains { max(abs($0.x - start.x), abs($0.y - start.y)) >= minimumDrag }
    }
}
