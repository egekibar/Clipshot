import Foundation

/// The user's shortcut, stored in UserDefaults as JSON. Anything missing, unreadable or unusable as a global
/// hotkey reads as ⌘P, so a damaged preference can never leave a bare letter registered system-wide.
public struct HotKeySettings {
    static let storageKey = "hotKey"
    let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var combo: KeyCombo {
        get {
            guard let data = defaults.data(forKey: Self.storageKey),
                let stored = try? JSONDecoder().decode(KeyCombo.self, from: data),
                stored.isValidHotKey
            else { return .defaultCombo }
            return stored
        }
        nonmutating set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.storageKey)
        }
    }
}
