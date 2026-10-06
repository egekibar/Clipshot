import AppKit
import ClipshotMarkup

/// The HUD under the frozen region: tools, colors, undo, cancel, copy. Every control has its key in its tooltip.
final class MarkupToolbar: NSView {
    var onTool: (MarkTool) -> Void = { _ in }
    var onColor: (MarkColor) -> Void = { _ in }
    var onUndo: () -> Void = {}
    var onCancel: () -> Void = {}
    var onCopy: () -> Void = {}

    static let tools: [(tool: MarkTool, symbol: String, name: String)] = [
        (.box, "rectangle", "Kutu (1)"),
        (.arrow, "arrow.up.right", "Ok (2)"),
        (.highlighter, "highlighter", "Fosforlu kalem (3)"),
        (.pen, "scribble.variable", "Serbest kalem (4)"),
    ]
    static let colorNames = ["Kırmızı", "Sarı", "Yeşil", "Mavi", "Beyaz", "Siyah"]

    private let toolPicker = NSSegmentedControl()
    private var dots: [ColorDot] = []
    private let undoButton = NSButton()

    init() {
        super.init(frame: .zero)
        // Dark HUD whatever the system appearance: it has to stand out on any screenshot.
        appearance = NSAppearance(named: .vibrantDark)
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Mirrors the session: the current tool, its color, whether there is anything to undo.
    func show(tool: MarkTool, color: MarkColor, canUndo: Bool) {
        toolPicker.selectedSegment = Self.tools.firstIndex { $0.tool == tool } ?? 0
        for dot in dots { dot.isSelected = dot.color == color }
        undoButton.isEnabled = canUndo
    }

    private func build() {
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = Self.roundedMask(radius: 11)
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        toolPicker.segmentCount = Self.tools.count
        toolPicker.trackingMode = .selectOne
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        for (index, tool) in Self.tools.enumerated() {
            let image = NSImage(systemSymbolName: tool.symbol, accessibilityDescription: tool.name)?
                .withSymbolConfiguration(symbolConfig)
            toolPicker.setImage(image, forSegment: index)
            toolPicker.setWidth(32, forSegment: index)
            toolPicker.setToolTip(tool.name, forSegment: index)
        }
        toolPicker.target = self
        toolPicker.action = #selector(toolPicked)

        dots = MarkColor.palette.enumerated().map { index, color in
            let dot = ColorDot(color: color) { [weak self] in self?.onColor($0) }
            dot.toolTip = Self.colorNames[index]
            dot.setAccessibilityLabel(Self.colorNames[index])
            return dot
        }
        let colors = NSStackView(views: dots)
        colors.spacing = 2

        configure(undoButton, symbol: "arrow.uturn.backward", tip: "Geri al (⌘Z)", action: #selector(undoClicked))
        let cancelButton = NSButton()
        configure(cancelButton, symbol: "xmark", tip: "Vazgeç (esc)", action: #selector(cancelClicked))
        let copyButton = NSButton(title: "Kopyala", target: self, action: #selector(copyClicked))
        copyButton.bezelStyle = .push
        copyButton.bezelColor = .controlAccentColor
        copyButton.toolTip = "İşaretli hali kopyala (↩)"

        let row = NSStackView(views: [toolPicker, colors, undoButton, cancelButton, copyButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.setCustomSpacing(14, after: toolPicker)
        row.setCustomSpacing(12, after: colors)
        row.setCustomSpacing(10, after: cancelButton)
        row.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 6)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func configure(_ button: NSButton, symbol: String, tip: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .white
        button.toolTip = tip
        button.target = self
        button.action = action
        button.widthAnchor.constraint(equalToConstant: 26).isActive = true
    }

    @objc private func toolPicked() { onTool(Self.tools[max(toolPicker.selectedSegment, 0)].tool) }
    @objc private func undoClicked() { onUndo() }
    @objc private func cancelClicked() { onCancel() }
    @objc private func copyClicked() { onCopy() }

    /// A stretchable rounded-rectangle mask for the blurred background.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// One color in the toolbar: a dot, ringed when it is the current tool's color.
private final class ColorDot: NSView {
    let color: MarkColor
    var isSelected = false {
        didSet { needsDisplay = true }
    }
    private let onPick: (MarkColor) -> Void

    init(color: MarkColor, onPick: @escaping (MarkColor) -> Void) {
        self.color = color
        self.onPick = onPick
        super.init(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var intrinsicContentSize: NSSize { NSSize(width: 20, height: 20) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onPick(color) }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected {
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
            ring.lineWidth = 2
            NSColor.white.setStroke()
            ring.stroke()
        }
        let dot = NSBezierPath(ovalIn: bounds.insetBy(dx: 4.5, dy: 4.5))
        NSColor(cgColor: color.cgColor)?.setFill()
        dot.fill()
        // Keeps the white and the black dot visible on the dark background.
        dot.lineWidth = 1
        NSColor(white: 1, alpha: 0.25).setStroke()
        dot.stroke()
    }
}
