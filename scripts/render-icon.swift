// Renders Clipshot's 1024x1024 app icon with CoreGraphics and writes it as a PNG.
// No .xcassets, no actool: `swift scripts/render-icon.swift out.png` runs in interpreter mode.
// Glyph: rounded-rect plate with a teal→blue gradient, a dashed selection marquee and the crosshair that drags it.
// (SF Symbols may not be used in app icons, so everything is drawn by hand.)
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024
guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: render-icon.swift <output.png>\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])

guard
    let context = CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else {
    FileHandle.standardError.write(Data("cannot create bitmap context\n".utf8))
    exit(1)
}

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let full = CGRect(x: 0, y: 0, width: Double(side), height: Double(side))

// 1. Rounded-rect plate. macOS icons leave a margin inside the 1024 pt canvas.
let plate = full.insetBy(dx: 100, dy: 100)
let platePath = CGPath(roundedRect: plate, cornerWidth: 190, cornerHeight: 190, transform: nil)
context.saveGState()
context.addPath(platePath)
context.clip()
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [color(0.13, 0.78, 0.76), color(0.16, 0.38, 0.93)] as CFArray,
    locations: [0, 1])!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: plate.minX, y: plate.maxY),
    end: CGPoint(x: plate.maxX, y: plate.minY),
    options: [])
context.restoreGState()

// 2. Selection marquee: a faint fill and a dashed white outline, like a region being dragged out.
//    The dashes stop short of the dragged corner, where the crosshair's arms carry the two edges on.
let selection = CGRect(x: plate.minX + 150, y: plate.minY + 250, width: 470, height: 360)
let corner = CGPoint(x: selection.maxX, y: selection.minY)  // bottom right; CoreGraphics' y axis points up
let arm = 118.0
let gap = 30.0
context.setFillColor(color(1, 1, 1, 0.16))
context.fill(selection)
context.setStrokeColor(color(1, 1, 1, 1))
context.setLineWidth(30)
context.setLineCap(.round)
let gapLength = 48.0
let clearance = arm + 40
/// One edge, its dash pattern stretched so it starts and ends on a whole dash (corners become clean Ls).
func dashedEdge(from start: CGPoint, to end: CGPoint) {
    let length = hypot(end.x - start.x, end.y - start.y)
    let count = max(1, ((length + gapLength) / 104).rounded())
    context.setLineDash(phase: 0, lengths: [(length + gapLength) / count - gapLength, gapLength])
    context.beginPath()
    context.move(to: start)
    context.addLine(to: end)
    context.strokePath()
}
let topLeft = CGPoint(x: selection.minX, y: selection.maxY)
let topRight = CGPoint(x: selection.maxX, y: selection.maxY)
let bottomLeft = CGPoint(x: selection.minX, y: selection.minY)
dashedEdge(from: topLeft, to: topRight)
dashedEdge(from: topLeft, to: bottomLeft)
dashedEdge(from: topRight, to: CGPoint(x: corner.x, y: corner.y + clearance))
dashedEdge(from: bottomLeft, to: CGPoint(x: corner.x - clearance, y: corner.y))
context.setLineDash(phase: 0, lengths: [])

// 3. Crosshair on the corner being dragged.
context.setStrokeColor(color(1, 1, 1, 1))
context.setLineWidth(30)
context.setLineCap(.round)
for (dx, dy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)] {
    context.beginPath()
    context.move(to: CGPoint(x: corner.x + dx * gap, y: corner.y + dy * gap))
    context.addLine(to: CGPoint(x: corner.x + dx * arm, y: corner.y + dy * arm))
    context.strokePath()
}

guard let image = context.makeImage() else {
    FileHandle.standardError.write(Data("cannot snapshot context\n".utf8))
    exit(1)
}
guard
    let destination = CGImageDestinationCreateWithURL(
        output as CFURL, UTType.png.identifier as CFString, 1, nil)
else {
    FileHandle.standardError.write(Data("cannot create PNG destination\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("cannot write PNG\n".utf8))
    exit(1)
}
print("wrote \(output.path) (\(side)x\(side))")
