import CoreGraphics

/// The four ways to mark a spot, in toolbar order (keys 1–4).
public enum MarkTool: String, CaseIterable, Sendable {
    case box, arrow, highlighter, pen
}

/// An opaque sRGB color; the highlighter adds its own transparency.
public struct MarkColor: Hashable, Sendable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let red = MarkColor(red: 1, green: 0.231, blue: 0.188)
    public static let yellow = MarkColor(red: 1, green: 0.839, blue: 0.039)
    public static let green = MarkColor(red: 0.204, green: 0.78, blue: 0.349)
    public static let blue = MarkColor(red: 0, green: 0.478, blue: 1)
    public static let white = MarkColor(red: 1, green: 1, blue: 1)
    public static let black = MarkColor(red: 0, green: 0, blue: 0)

    /// The toolbar's color dots, in order.
    public static let palette: [MarkColor] = [.red, .yellow, .green, .blue, .white, .black]

    public var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
}

/// One mark, in image points with the origin top-left. Box, arrow and highlighter keep their start and end;
/// the pen keeps every sample of its path.
public struct Mark: Equatable, Sendable {
    public var tool: MarkTool
    public var color: MarkColor
    public var points: [CGPoint]

    public init(tool: MarkTool, color: MarkColor, points: [CGPoint]) {
        self.tool = tool
        self.color = color
        self.points = points
    }
}
