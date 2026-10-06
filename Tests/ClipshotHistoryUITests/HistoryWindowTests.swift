import AppKit
import Foundation
import Testing

@testable import ClipshotHistoryUI

@MainActor
@Suite("HistoryWindow")
struct HistoryWindowTests {
    /// Esc closes Geçmiş the way its close button does, whether the grid has the keyboard (after a click) or the
    /// window itself does (just opened). The key press goes through the window's own event handling, unshown.
    @Test(arguments: [false, true])
    func escapeClosesTheWindow(gridHasFocus: Bool) throws {
        _ = NSApplication.shared
        var closes = 0
        let controller = HistoryWindowController(
            actions: .init(
                items: { [] }, thumbnailURL: { _ in URL(fileURLWithPath: "/dev/null") }, historyDays: { 3 },
                open: { _ in }, copy: { _ in }, delete: { _ in }, showSettings: {}, closed: { closes += 1 }))
        controller.prepare()
        let window = try #require(controller.window)
        let grid = try #require(descendant(of: window.contentView, as: NSCollectionView.self))
        #expect(window.makeFirstResponder(gridHasFocus ? grid : nil))

        window.sendEvent(try escape(in: window))

        #expect(closes == 1)
    }
}

/// The key press Esc makes, aimed at `window`.
private func escape(in window: NSWindow) throws -> NSEvent {
    try #require(
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
}

private func descendant<View: NSView>(of view: NSView?, as type: View.Type) -> View? {
    guard let view else { return nil }
    if let match = view as? View { return match }
    return view.subviews.lazy.compactMap { descendant(of: $0, as: type) }.first
}
