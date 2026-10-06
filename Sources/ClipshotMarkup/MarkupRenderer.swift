import CoreGraphics
import Foundation
import ImageIO

/// How marks look. The canvas on screen and the image on the clipboard draw through the same code, so what you see
/// is what you paste.
public enum MarkDrawing {
    public static let lineWidth: CGFloat = 3
    static let highlightAlpha: CGFloat = 0.4
    static let arrowheadLength: CGFloat = 14
    static let arrowheadAngle: CGFloat = .pi / 7

    /// Draws into a context whose user space is image points with the origin top-left.
    public static func draw(_ marks: [Mark], in context: CGContext) {
        for mark in marks { draw(mark, in: context) }
    }

    public static func draw(_ mark: Mark, in context: CGContext) {
        guard let start = mark.points.first, let end = mark.points.last else { return }
        context.saveGState()
        defer { context.restoreGState() }
        let color = mark.color.cgColor
        switch mark.tool {
        case .highlighter:
            // Translucent rather than multiplied: it has to show on dark screenshots too.
            context.setFillColor(color.copy(alpha: highlightAlpha) ?? color)
            context.fill(MarkupGeometry.rect(from: start, to: end))
        case .box:
            setStroke(color, in: context)
            let rect = MarkupGeometry.rect(from: start, to: end)
            let radius = min(3, rect.width / 2, rect.height / 2)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.strokePath()
        case .arrow:
            setStroke(color, in: context)
            let (left, right) = MarkupGeometry.arrowhead(
                from: start, to: end, length: arrowheadLength, angle: arrowheadAngle)
            // The shaft stops inside the head, so its round cap never pokes out past the point.
            context.move(to: start)
            context.addLine(to: CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2))
            context.strokePath()
            context.setFillColor(color)
            context.move(to: end)
            context.addLine(to: left)
            context.addLine(to: right)
            context.closePath()
            context.fillPath()
        case .pen:
            setStroke(color, in: context)
            context.addPath(smoothPath(through: mark.points))
            context.strokePath()
        }
    }

    private static func setStroke(_ color: CGColor, in context: CGContext) {
        context.setStrokeColor(color)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        // A soft shadow keeps a red mark readable on red or busy backgrounds.
        context.setShadow(offset: .zero, blur: 2, color: CGColor(gray: 0, alpha: 0.35))
    }

    /// Quadratic curves through the midpoints of the mouse samples: a hand-drawn line without their jitter.
    static func smoothPath(through points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 2 else {
            for point in points.dropFirst() { path.addLine(to: point) }
            return path
        }
        for index in 1..<(points.count - 1) {
            let next = points[index + 1]
            let middle = CGPoint(x: (points[index].x + next.x) / 2, y: (points[index].y + next.y) / 2)
            path.addQuadCurve(to: middle, control: points[index])
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}

/// The marked screenshot that goes to the clipboard.
public enum MarkupRenderer {
    /// The screenshot with its marks at the screenshot's own pixel size (`scale` pixels per point) and color space.
    public static func render(_ image: CGImage, marks: [Mark], scale: CGFloat) -> CGImage? {
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        let space = image.colorSpace.flatMap { $0.supportsOutput ? $0 : nil } ?? sRGB
        guard
            let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        // From here on: image points, origin top-left.
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: scale, y: -scale)
        MarkDrawing.draw(marks, in: context)
        return context.makeImage()
    }

    public static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
