import AppKit
import ClipshotMarkup
import Foundation
import Testing

@testable import ClipshotMarkupUI

/// A fake 2× screenshot: a window with a title, lines of text and a blue button.
func sampleScreenshot() -> CGImage {
    let width = 840
    let height = 520
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: 2, y: 2)
    context.setFillColor(CGColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 420, height: 260))
    context.setFillColor(CGColor(srgbRed: 0.88, green: 0.88, blue: 0.9, alpha: 1))
    context.fill(CGRect(x: 0, y: 228, width: 420, height: 32))
    context.setFillColor(CGColor(gray: 0.55, alpha: 1))
    for (index, width) in [300, 260, 330, 180, 280].enumerated() {
        context.fill(CGRect(x: 24, y: 190 - CGFloat(index) * 26, width: CGFloat(width), height: 10))
    }
    context.setFillColor(CGColor(srgbRed: 0, green: 0.48, blue: 1, alpha: 1))
    context.fill(CGRect(x: 290, y: 20, width: 100, height: 30))
    return context.makeImage()!
}

/// `CLIPSHOT_PREVIEW=1 make test FILTER='MarkupPreview'` writes the panel as it looks to
/// $TMPDIR/clipshot-markup-preview.png, for eyes rather than assertions. Nothing is shown on screen.
@MainActor
@Suite("MarkupPreview", .enabled(if: ProcessInfo.processInfo.environment["CLIPSHOT_PREVIEW"] == "1"))
struct MarkupPreviewTests {
    @Test func rendersThePanel() throws {
        _ = NSApplication.shared
        var session = MarkupSession(image: sampleScreenshot(), scale: 2)
        let strokes: [(MarkTool, [(CGFloat, CGFloat)])] = [
            (.box, [(282, 206), (398, 246)]),
            (.arrow, [(180, 150), (232, 98)]),
            (.highlighter, [(20, 64), (338, 80)]),
            (.pen, [(20, 140), (60, 128), (100, 146), (140, 130), (180, 142)]),
        ]
        for (tool, points) in strokes {
            session.document.tool = tool
            session.document.begin(at: CGPoint(x: points[0].0, y: points[0].1))
            for point in points.dropFirst() { session.document.drag(to: CGPoint(x: point.0, y: point.1)) }
            session.document.end()
        }
        session.document.tool = .box
        let placement = MarkupGeometry.Placement(
            frame: CGRect(x: 200, y: 300, width: 420, height: 260), imageSize: CGSize(width: 420, height: 260),
            isInPlace: true)
        let content = MarkupPanelController.makeContent(
            session: session, placement: placement, visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        content.toolbar.show(tool: .box, color: .red, canUndo: true)

        let backdrop = NSView(frame: CGRect(origin: .zero, size: content.layout.panel.size).insetBy(dx: -24, dy: -24))
        backdrop.wantsLayer = true
        backdrop.layer?.backgroundColor = NSColor(white: 0.3, alpha: 1).cgColor
        content.view.setFrameOrigin(CGPoint(x: 24, y: 24))
        backdrop.addSubview(content.view)
        backdrop.layoutSubtreeIfNeeded()

        let rep = try #require(backdrop.bitmapImageRepForCachingDisplay(in: backdrop.bounds))
        backdrop.cacheDisplay(in: backdrop.bounds, to: rep)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clipshot-markup-preview.png")
        try png.write(to: url)
        print("preview: \(url.path) \(content.layout)")
    }
}
