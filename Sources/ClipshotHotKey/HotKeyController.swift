import ClipshotCore

/// Owns the one global shortcut. It registers the saved combo, lets it go while paused (so ⌘P prints again)
/// or while the recorder listens (so pressing the current combo is recorded instead of starting a capture),
/// and saves a newly recorded combo only once Carbon has accepted it.
@MainActor
public final class HotKeyController {
    public private(set) var isPaused = false
    public private(set) var isRecording = false
    /// Why the saved combo is not active although it should be; nil while it works, is paused or is recording.
    public private(set) var registrationError: HotKeyError?

    private let service: CarbonHotKeyService
    private let settings: HotKeySettings
    private let onPress: @Sendable () -> Void

    public init(
        service: CarbonHotKeyService = CarbonHotKeyService(), settings: HotKeySettings,
        onPress: @escaping @Sendable () -> Void
    ) {
        self.service = service
        self.settings = settings
        self.onPress = onPress
    }

    /// The shortcut the user chose (⌘P until they record another one).
    public var combo: KeyCombo { settings.combo }

    public func start() { apply() }

    public func setPaused(_ paused: Bool) {
        isPaused = paused
        apply()
    }

    public func beginRecording() {
        isRecording = true
        apply()
    }

    /// nil: the recording was cancelled and the saved combo comes back (unless paused).
    /// A combo: registered, saved and the pause ended; or the Carbon error is thrown, nothing is registered and
    /// recording goes on, so the user can try another combo.
    public func finishRecording(with newCombo: KeyCombo?) throws(HotKeyError) {
        guard let newCombo else {
            isRecording = false
            apply()
            return
        }
        try service.register(newCombo, handler: onPress)
        settings.combo = newCombo
        isRecording = false
        isPaused = false
        registrationError = nil
    }

    /// Registers the saved combo when it should be live and releases it otherwise.
    private func apply() {
        guard !isPaused, !isRecording else {
            service.unregister()
            registrationError = nil
            return
        }
        guard service.registeredCombo != settings.combo else { return }
        do {
            try service.register(settings.combo, handler: onPress)
            registrationError = nil
        } catch {
            registrationError = error
        }
    }
}
