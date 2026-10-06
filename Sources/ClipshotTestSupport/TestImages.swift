import CoreGraphics

/// A plain image of one color, `width` × `height` pixels.
public func solidImage(width: Int, height: Int, gray: CGFloat) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

/// The pixel `x` columns from the left and `y` rows from the top, as 0…1 sRGB components.
public func pixel(_ image: CGImage, x: Int, y: Int) -> (r: Double, g: Double, b: Double) {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let context = CGContext(
        data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let offset = (y * image.width + x) * 4
    return (Double(bytes[offset]) / 255, Double(bytes[offset + 1]) / 255, Double(bytes[offset + 2]) / 255)
}

public func isRed(_ p: (r: Double, g: Double, b: Double)) -> Bool { p.r > 0.8 && p.g < 0.45 && p.b < 0.45 }
public func isWhite(_ p: (r: Double, g: Double, b: Double)) -> Bool { p.r > 0.95 && p.g > 0.95 && p.b > 0.95 }
