import AppKit
import ClipshotCore
import ClipshotHistory
import ClipshotMarkup
import ClipshotTestSupport
import Foundation
import Testing

@testable import ClipshotHistoryUI

/// A fake 2× screenshot: a window with a colored title bar, lines of text and a button.
func fakeScreenshot(width: Int, height: Int, tint: CGColor) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(tint)
    context.fill(CGRect(x: 0, y: height - 56, width: width, height: 56))
    context.setFillColor(CGColor(gray: 0.6, alpha: 1))
    for row in 0..<5 {
        context.fill(CGRect(x: 40, y: height - 110 - row * 46, width: width - 160 - (row % 2) * 120, height: 18))
    }
    return context.makeImage()!
}

/// Draws a window's content offscreen. A never-shown window draws nothing into the cache, so the content is moved
/// out of it first, at the same size.
func render(contentOf window: NSWindow?, to name: String) throws -> URL {
    let window = try #require(window)
    let view = try #require(window.contentView)
    let size = view.frame.size
    window.contentView = NSView()
    view.frame = CGRect(origin: .zero, size: size)
    return try render(view, to: name)
}

func render(_ view: NSView, to name: String) throws -> URL {
    // Dynamic colors (labelColor and the like) need an appearance to resolve against outside a window.
    let appearance = try #require(NSAppearance(named: .aqua))
    view.appearance = appearance
    view.layoutSubtreeIfNeeded()
    let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    appearance.performAsCurrentDrawingAppearance { view.cacheDisplay(in: view.bounds, to: rep) }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    try #require(rep.representation(using: .png, properties: [:])).write(to: url)
    return url
}

/// `CLIPSHOT_PREVIEW=1 make test FILTER='HistoryPreview'` writes Geçmiş and Ayarlar as they look to
/// $TMPDIR/clipshot-history-preview.png and $TMPDIR/clipshot-settings-preview.png. Nothing is shown on screen.
@MainActor
@Suite("HistoryPreview", .enabled(if: ProcessInfo.processInfo.environment["CLIPSHOT_PREVIEW"] == "1"))
struct HistoryPreviewTests {
    @Test func rendersTheHistoryWindow() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipshot-preview-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let now = Date()
        let hour: TimeInterval = 3600
        let tints = [
            CGColor(srgbRed: 0.2, green: 0.5, blue: 0.95, alpha: 1),
            CGColor(srgbRed: 0.95, green: 0.6, blue: 0.2, alpha: 1),
            CGColor(srgbRed: 0.3, green: 0.75, blue: 0.4, alpha: 1),
            CGColor(srgbRed: 0.6, green: 0.4, blue: 0.85, alpha: 1),
        ]
        let shots: [(TimeInterval, Int, Int, Bool)] = [
            (0.2, 1200, 760, true), (1.5, 900, 900, false), (3, 1600, 700, false), (26, 1000, 640, true),
            (28, 1400, 800, false), (51, 800, 500, false),
        ]
        for (index, shot) in shots.enumerated() {
            let item = try store.add(
                fakeScreenshot(width: shot.1, height: shot.2, tint: tints[index % tints.count]), scale: 2,
                date: now - shot.0 * hour)
            if shot.3 {
                try store.update(
                    item.id,
                    marks: [Mark(tool: .box, color: .red, points: [CGPoint(x: 30, y: 60), CGPoint(x: 260, y: 140)])])
            }
        }
        let controller = HistoryWindowController(
            actions: .init(
                items: { store.items() }, thumbnailURL: { store.thumbnailURL(of: $0) }, historyDays: { 3 },
                open: { _ in }, copy: { _ in }, delete: { _ in }, showSettings: {}, closed: {}))
        controller.prepare()
        print("history preview: \(try render(contentOf: controller.window, to: "clipshot-history-preview.png").path)")
    }

    @Test func rendersTheSettingsWindow() throws {
        _ = NSApplication.shared
        let controller = SettingsWindowController(
            preferences: AppPreferences(store: MemoryPreferenceStore()), onHistoryDaysChange: {},
            confirmClear: { false }, onClearHistory: {}, onClose: {})
        controller.prepare()
        print("settings preview: \(try render(contentOf: controller.window, to: "clipshot-settings-preview.png").path)")
    }
}
