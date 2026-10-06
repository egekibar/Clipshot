import AppKit
import ClipshotCore
import ClipshotHotKey

/// "Kısayolu Değiştir…": a small window that takes the next key combination as the new shortcut.
///
/// Carbon wants a virtual key code, so recording goes through a local NSEvent monitor. It only sees events
/// already addressed to this app, so no permission is involved, and it runs before key equivalents, so every
/// combination reaches the recorder. The global shortcut is released meanwhile (HotKeyController), otherwise
/// pressing the current combo would start a capture instead of being recorded.
final class ShortcutRecorderController: NSObject, NSWindowDelegate {
    private let hotKeys: HotKeyController
    private let onChange: () -> Void
    private var window: NSWindow?
    private var monitor: Any?
    private let comboLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(wrappingLabelWithString: "")

    private static let hint =
        "⌘, ⌃ veya ⌥ içeren bir kombinasyona ya da tek başına bir F tuşuna bas. Vazgeçmek için esc."

    init(hotKeys: HotKeyController, onChange: @escaping () -> Void) {
        self.hotKeys = hotKeys
        self.onChange = onChange
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        if !hotKeys.isRecording {
            hotKeys.beginRecording()
            onChange()
        }
        comboLabel.stringValue = hotKeys.combo.label
        setHint(Self.hint, isError: false)
        startMonitor()
        // A menu bar app is never frontmost on its own; the window needs key focus to receive the combo.
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Closing without a new combo (Vazgeç, esc, the title bar button) brings the saved one back.
        if hotKeys.isRecording { try? hotKeys.finishRecording(with: nil) }
        stopMonitor()
        onChange()
        Alerts.yieldFocusIfDone()
    }

    /// Clicking away cancels: the shortcut is released while the recorder listens, so a forgotten window would leave
    /// ⌘P printing again in every app.
    func windowDidResignKey(_ notification: Notification) {
        // A window that is closing resigns key too; by then the recording is already over.
        if hotKeys.isRecording { window?.close() }
    }

    private func startMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Alerts and other windows keep their keys; only the recorder's are taken.
            guard let self, let window = self.window, event.window === window else { return event }
            self.handle(event)
            return nil
        }
    }

    private func stopMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags
        let modifiers = KeyCombo.modifierMask(
            command: flags.contains(.command), shift: flags.contains(.shift),
            option: flags.contains(.option), control: flags.contains(.control))
        let input = RecorderInput.interpret(
            keyCode: UInt32(event.keyCode), modifiers: modifiers,
            characters: event.characters(byApplyingModifiers: []) ?? "")
        switch input {
        case .cancel:
            window?.close()
        case .rejected:
            setHint("Bu kombinasyon kullanılamaz: ⌘, ⌃ veya ⌥ ile birlikte bas.", isError: true)
        case .reserved(let label):
            setHint("\(label) her uygulamada düzenleme için gerekli; başka bir kombinasyon seç.", isError: true)
        case .combo(let combo):
            apply(combo)
        }
    }

    private func apply(_ combo: KeyCombo) {
        comboLabel.stringValue = combo.label
        do {
            try hotKeys.finishRecording(with: combo)
        } catch {
            setHint("\(combo.label): \(Alerts.describe(error)) Başka bir kombinasyon dene.", isError: true)
            return
        }
        AppLog.app.notice("shortcut changed to \(combo.label, privacy: .public)")
        window?.close()
    }

    @objc private func resetClicked() { apply(.defaultCombo) }
    @objc private func cancelClicked() { window?.close() }

    private func setHint(_ text: String, isError: Bool) {
        hintLabel.stringValue = text
        hintLabel.textColor = isError ? .systemOrange : .secondaryLabelColor
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 190),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Kısayolu Değiştir"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = self

        let title = NSTextField(labelWithString: "Yeni kısayola bas")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        comboLabel.font = .systemFont(ofSize: 30, weight: .medium)
        comboLabel.alignment = .center
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.alignment = .center
        hintLabel.preferredMaxLayoutWidth = 330

        let reset = NSButton(
            title: "Varsayılan (\(KeyCombo.defaultCombo.label))", target: self, action: #selector(resetClicked))
        let cancel = NSButton(title: "Vazgeç", target: self, action: #selector(cancelClicked))
        // Buttons never take keyboard focus: every key press belongs to the recorder.
        reset.refusesFirstResponder = true
        cancel.refusesFirstResponder = true
        let buttons = NSStackView(views: [reset, cancel])
        buttons.orientation = .horizontal
        buttons.spacing = 12

        let stack = NSStackView(views: [title, comboLabel, hintLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
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
        return window
    }
}
