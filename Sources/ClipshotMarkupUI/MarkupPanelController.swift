import AppKit
import ClipshotMarkup

/// Becomes key without activating Clipshot (`.nonactivatingPanel`), so the app the user was in keeps its menus and
/// gets the keyboard straight back when the panel closes. The same setup as Shotcue's quick panel, which is known
/// to take keystrokes this way.
final class MarkupPanel: NSPanel {
    /// Without `.titled`, a non-activating panel cannot become key by default and would never see a key press.
    override var canBecomeKey: Bool { true }

    /// Never the main window: that is what would make Clipshot look activated.
    override var canBecomeMain: Bool { false }
}

/// The in-place marking panel: the screenshot frozen exactly where it was taken, a frame around it, the toolbar
/// beneath. ↩ / ⌘C / Kopyala or clicking anywhere else keep the marks; Esc / ✕ drop them.
public final class MarkupPanelController: NSObject, NSWindowDelegate {
    /// The marked screenshot, for the clipboard. Not called when nothing was drawn or the marks were dropped.
    private let onCopy: (CGImage) -> Void
    /// After every close, whatever happened.
    private let onClose: () -> Void
    private var panel: MarkupPanel?
    private var canvas: MarkupCanvasView?
    private var toolbar: MarkupToolbar?
    private var keyMonitor: Any?

    public init(onCopy: @escaping (CGImage) -> Void, onClose: @escaping () -> Void) {
        self.onCopy = onCopy
        self.onClose = onClose
    }

    public var isOpen: Bool { panel != nil }

    /// Shows `image` at `placement`. A panel that is still open is finished first, keeping its marks.
    public func present(image: CGImage, placement: MarkupGeometry.Placement, visibleFrame: CGRect) {
        finish(keepingMarks: true)
        let scale = CGFloat(image.width) / placement.imageSize.width
        let content = Self.makeContent(
            session: MarkupSession(image: image, scale: scale), placement: placement, visibleFrame: visibleFrame)

        let panel = MarkupPanel(
            contentRect: content.layout.panel, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        // Above the menu bar, so a region taken across it is covered too; menus still open above it.
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.contentView = content.view
        panel.delegate = self

        content.canvas.onChange = { [weak self] in self?.refreshToolbar() }
        content.toolbar.onTool = { [weak self] in self?.perform(.tool($0)) }
        content.toolbar.onColor = { [weak self] color in
            self?.canvas?.session.document.color = color
            self?.refreshToolbar()
        }
        content.toolbar.onUndo = { [weak self] in self?.perform(.undo) }
        content.toolbar.onCancel = { [weak self] in self?.perform(.cancel) }
        content.toolbar.onCopy = { [weak self] in self?.perform(.copy) }

        self.panel = panel
        canvas = content.canvas
        toolbar = content.toolbar
        refreshToolbar()
        // Keys are taken before any view or key equivalent sees them, and only the panel's own (Shotcue's
        // PanelKeyMonitor does the same, after SwiftUI shortcuts proved unreliable in such a panel).
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
            guard let self, let panel, event.window === panel else { return event }
            return self.handle(event) ? nil : event
        }
        // Never NSApp.activate: the panel takes the keyboard without pulling the user out of their app.
        panel.makeKeyAndOrderFront(nil)
    }

    /// Closes the panel. With `keepingMarks`, a screenshot that has marks goes to the clipboard first.
    public func finish(keepingMarks: Bool) {
        guard let panel, let canvas else { return }
        self.panel = nil
        self.canvas = nil
        toolbar = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel.delegate = nil
        panel.orderOut(nil)
        var session = canvas.session
        if let marked = session.finish(keepingMarks: keepingMarks) { onCopy(marked) }
        onClose()
    }

    /// Clicking anywhere outside the panel counts as done: the marks are kept.
    public func windowDidResignKey(_ notification: Notification) {
        finish(keepingMarks: true)
    }

    func perform(_ action: MarkupAction) {
        switch action {
        case .tool(let tool): canvas?.session.document.tool = tool
        case .undo: canvas?.session.document.undo()
        case .copy: finish(keepingMarks: true)
        case .cancel: finish(keepingMarks: false)
        }
        refreshToolbar()
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard
            let action = MarkupKeys.action(
                keyCode: event.keyCode, characters: event.charactersIgnoringModifiers ?? "",
                command: event.modifierFlags.contains(.command))
        else { return false }
        perform(action)
        return true
    }

    private func refreshToolbar() {
        guard let canvas, let toolbar else { return }
        let document = canvas.session.document
        toolbar.show(tool: document.tool, color: document.color, canUndo: !document.marks.isEmpty)
    }

    /// The panel's content: frame, canvas and toolbar laid out by `MarkupGeometry.panelLayout`.
    static func makeContent(session: MarkupSession, placement: MarkupGeometry.Placement, visibleFrame: CGRect) -> (
        view: NSView, layout: MarkupGeometry.PanelLayout, canvas: MarkupCanvasView, toolbar: MarkupToolbar
    ) {
        let toolbar = MarkupToolbar()
        let toolbarSize = toolbar.fittingSize
        let layout = MarkupGeometry.panelLayout(placement: placement, toolbar: toolbarSize, visibleFrame: visibleFrame)
        let view = NSView(frame: CGRect(origin: .zero, size: layout.panel.size))
        let frame = MarkupFrameView(frame: layout.border)
        let canvas = MarkupCanvasView(
            session: session, imageSize: placement.imageSize, displaySize: layout.canvas.size)
        canvas.frame = layout.canvas
        canvas.bounds = CGRect(origin: .zero, size: placement.imageSize)
        toolbar.frame = layout.toolbar
        view.addSubview(frame)
        view.addSubview(canvas)
        // Last, so a toolbar that has to sit inside a full-screen canvas stays on top of it.
        view.addSubview(toolbar)
        return (view, layout, canvas, toolbar)
    }
}
