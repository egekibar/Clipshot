import AppKit
import ClipshotMarkup

/// Where the user dragged during `screencapture -i`: the first mouse-down and the last mouse-up seen by a global
/// monitor. Watching another app's mouse events needs no permission (only key events would).
final class SelectionTracker {
    private var monitor: Any?
    private var down: CGPoint?
    private var up: CGPoint?

    func begin() {
        _ = end()
        down = nil
        up = nil
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            // A global event has no window: its location is already in screen points.
            let point = event.locationInWindow
            let isDown = event.type == .leftMouseDown
            MainActor.assumeIsolated {
                guard let self else { return }
                if isDown {
                    if self.down == nil { self.down = point }
                } else {
                    self.up = point
                }
            }
        }
    }

    /// The dragged rectangle in screen points; nil when no drag was seen. The mouse-up can still be queued when the
    /// capture ends, so the pointer's current position, where the button was just released, stands in for it.
    func end() -> CGRect? {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard let down else { return nil }
        return MarkupGeometry.rect(from: down, to: up ?? NSEvent.mouseLocation)
    }
}

/// The screenshot on the general pasteboard.
enum ClipboardImage {
    /// What screencapture just copied: PNG, or TIFF from older tools.
    static func read() -> CGImage? {
        let pasteboard = NSPasteboard.general
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            guard let data = pasteboard.data(forType: type),
                let source = CGImageSourceCreateWithData(data as CFData, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { continue }
            return image
        }
        return nil
    }

    /// PNG for most apps and TIFF for older ones, as one item. The resolution is kept (`scale` pixels per point), so
    /// a Retina screenshot pastes at its real size rather than twice as big.
    static func write(_ image: CGImage, scale: CGFloat) -> Bool {
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = NSSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        if let tiff = rep.tiffRepresentation { item.setData(tiff, forType: .tiff) }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }
}
