import Carbon.HIToolbox
import ClipshotCore
import Foundation

public enum HotKeyError: Error, Equatable, Sendable {
    /// Non-zero OSStatus from InstallEventHandler or RegisterEventHotKey.
    /// -9878 (eventHotKeyExistsErr): this process already holds that combination. Carbon does not refuse a combo
    /// another app has registered (measured 2026-10-06: `make test` registers ⌘P while Clipshot.app holds it).
    case registrationFailed(OSStatus)
}

/// Retains the Swift closure so Carbon can carry it as opaque userData.
/// EventHandlerUPP is a C function pointer and cannot capture context.
private final class HotKeyHandlerBox {
    let handler: @Sendable () -> Void
    init(_ handler: @escaping @Sendable () -> Void) { self.handler = handler }
}

/// Global hotkey through Carbon `RegisterEventHotKey` — the only mechanism that needs no TCC permission at
/// all. `NSEvent.addGlobalMonitorForEvents` would need Accessibility and `CGEvent.tapCreate` Input Monitoring,
/// and both would see every keystroke (Shotcue research §5).
///
/// One combination at a time. Registering again replaces the previous registration, because Carbon rejects a
/// second registration of the same combo with eventHotKeyExistsErr. A registered combo is delivered to this
/// app before the frontmost app sees it, which is how ⌘P stops reaching Print while Clipshot holds it.
///
/// Main thread only: Carbon event APIs are not thread safe.
public final class CarbonHotKeyService: @unchecked Sendable {
    private let lock = NSLock()
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var box: HotKeyHandlerBox?
    private var combo: KeyCombo?

    /// 'CLPS' — lets the handler ignore hotkeys registered by anything else in this process.
    static let signature: OSType = 0x434C_5053

    public init() {}

    /// The combination Carbon currently holds; nil before `register` and after `unregister`.
    public var registeredCombo: KeyCombo? { lock.withLock { combo } }

    public func register(_ combo: KeyCombo, handler: @escaping @Sendable () -> Void) throws(HotKeyError) {
        dispatchPrecondition(condition: .onQueue(.main))
        lock.lock()
        defer { lock.unlock() }
        teardownLocked()

        let newBox = HotKeyHandlerBox(handler)
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // Captures nothing: it reads the box back out of userData, so it converts to a C pointer.
        let callback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr, hotKeyID.signature == CarbonHotKeyService.signature else {
                return OSStatus(eventNotHandledErr)
            }
            let handler = Unmanaged<HotKeyHandlerBox>.fromOpaque(userData)
                .takeUnretainedValue().handler
            // The handler starts a capture: AppKit work, main queue only.
            DispatchQueue.main.async { handler() }
            return noErr
        }

        var newEventHandler: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(), callback, 1, &eventType,
            Unmanaged.passUnretained(newBox).toOpaque(), &newEventHandler)
        guard installStatus == noErr else { throw .registrationFailed(installStatus) }

        var newHotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        // keyCode and modifiers are already Carbon values in Core (KeyCombo), no conversion.
        let registerStatus = RegisterEventHotKey(
            combo.keyCode, combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &newHotKeyRef)
        guard registerStatus == noErr, let newHotKeyRef else {
            if let newEventHandler { RemoveEventHandler(newEventHandler) }
            throw .registrationFailed(registerStatus)
        }

        // Holding the box keeps the closure alive for as long as Carbon holds the raw pointer.
        box = newBox
        eventHandler = newEventHandler
        hotKeyRef = newHotKeyRef
        self.combo = combo
    }

    public func unregister() {
        dispatchPrecondition(condition: .onQueue(.main))
        lock.lock()
        defer { lock.unlock() }
        teardownLocked()
    }

    deinit {
        // Only a live registration makes Carbon calls here; an idle service may be released anywhere.
        if hotKeyRef != nil || eventHandler != nil { dispatchPrecondition(condition: .onQueue(.main)) }
        teardownLocked()
    }

    /// Caller holds `lock` (or is deinit, where no other reference can exist).
    private func teardownLocked() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
        box = nil
        combo = nil
    }
}
