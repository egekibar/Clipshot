import Carbon.HIToolbox
import ClipshotCore
import Foundation
import Synchronization
import Testing

/// Carbon hotkeys are process-wide, so every test that registers one runs inside this serialized suite:
/// two tests holding the same combo at once would fail each other with eventHotKeyExistsErr.
@MainActor
@Suite(.serialized)
enum CarbonSuite {}

extension KeyCombo {
    /// Combos no app on a real Mac uses, so `make test` never steals a working shortcut, even for a moment.
    static let testA = KeyCombo(keyCode: 0x40, modifiers: controlKey | optionKey | shiftKey, label: "⌃⌥⇧F17")
    static let testB = KeyCombo(keyCode: 0x4F, modifiers: controlKey | optionKey | shiftKey, label: "⌃⌥⇧F18")
}

/// eventHotKeyExistsErr from CarbonEvents.h: another registration in this process already holds the combo.
let hotKeyExistsStatus = OSStatus(-9878)

/// Counts hotkey presses from the @Sendable handler Carbon calls.
final class PressCounter: Sendable {
    private let count = Mutex(0)
    var value: Int { count.withLock { $0 } }
    func press() { count.withLock { $0 += 1 } }
}

/// A private defaults domain per test, removed again when the test ends.
final class ScratchDefaults {
    let name = "clipshot-tests-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() { defaults = UserDefaults(suiteName: name)! }
    deinit { defaults.removePersistentDomain(forName: name) }
}

struct CarbonEventError: Error {
    let status: OSStatus
}

/// Delivers a kEventHotKeyPressed to this process's application target the way the window server does
/// when the registered keys are pressed. Returns the handler's verdict: noErr when a handler took it.
/// No real key press is needed, so this works headless and needs no permission.
@discardableResult
func sendHotKeyPressed(signature: OSType, id: UInt32 = 1) throws -> OSStatus {
    var event: EventRef?
    let created = CreateEvent(
        nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), GetCurrentEventTime(),
        EventAttributes(kEventAttributeNone), &event)
    guard created == noErr, let event else { throw CarbonEventError(status: created) }
    defer { ReleaseEvent(event) }
    var hotKeyID = EventHotKeyID(signature: signature, id: id)
    let set = SetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        MemoryLayout<EventHotKeyID>.size, &hotKeyID)
    guard set == noErr else { throw CarbonEventError(status: set) }
    return SendEventToEventTarget(event, GetApplicationEventTarget())
}

/// The handler hops to the main queue; yield until the press arrives (bounded, so a missing call fails fast).
@MainActor
func waitForPresses(_ counter: PressCounter, atLeast expected: Int) async {
    for _ in 0..<1000 where counter.value < expected { await Task.yield() }
}
