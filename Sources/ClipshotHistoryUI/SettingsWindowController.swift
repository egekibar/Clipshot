import AppKit
import ClipshotCore

/// "Ayarlar": how many days Geçmiş keeps, and clearing it.
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let preferences: AppPreferences
    private let onHistoryDaysChange: () -> Void
    /// True when the user confirmed; the history is then cleared.
    private let confirmClear: () -> Bool
    private let onClearHistory: () -> Void
    private let onClose: () -> Void
    private(set) var window: NSWindow?
    private let stepper = NSStepper()
    private let daysLabel = NSTextField(labelWithString: "")

    public init(
        preferences: AppPreferences, onHistoryDaysChange: @escaping () -> Void, confirmClear: @escaping () -> Bool,
        onClearHistory: @escaping () -> Void, onClose: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.onHistoryDaysChange = onHistoryDaysChange
        self.confirmClear = confirmClear
        self.onClearHistory = onClearHistory
        self.onClose = onClose
    }

    public func show() {
        prepare()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// The window, built and filled but not shown.
    func prepare() {
        if window == nil { window = makeWindow() }
        stepper.integerValue = preferences.historyDays
        showDays()
    }

    public func windowWillClose(_ notification: Notification) {
        onClose()
    }

    @objc private func daysChanged() {
        preferences.historyDays = stepper.integerValue
        showDays()
        onHistoryDaysChange()
    }

    @objc private func clearClicked() {
        guard confirmClear() else { return }
        onClearHistory()
    }

    private func showDays() {
        daysLabel.stringValue = "\(preferences.historyDays) gün"
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 170), styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = "Ayarlar"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let title = NSTextField(labelWithString: "Geçmişi sakla:")
        stepper.minValue = Double(AppPreferences.historyDaysRange.lowerBound)
        stepper.maxValue = Double(AppPreferences.historyDaysRange.upperBound)
        stepper.increment = 1
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = #selector(daysChanged)
        daysLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        daysLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        let row = NSStackView(views: [title, daysLabel, stepper])
        row.spacing = 8

        let hint = NSTextField(
            wrappingLabelWithString:
                "Daha eski ekran görüntüleri kendiliğinden silinir. Görüntüler yalnızca bu Mac'te, "
                + "~/Library/Application Support/Clipshot içinde durur.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = 400

        let clear = NSButton(title: "Geçmişi Temizle…", target: self, action: #selector(clearClicked))
        clear.bezelStyle = .push

        let stack = NSStackView(views: [row, hint, clear])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
        window.setContentSize(stack.fittingSize)
        window.center()
        return window
    }
}
