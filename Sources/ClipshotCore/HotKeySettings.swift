import Foundation

/// The user's shortcut, stored as JSON in the preferences (UserDefaults in the app). Anything missing, unreadable or
/// unusable as a global hotkey reads as ⌘P, so a damaged preference can never leave a bare letter registered
/// system-wide.
public struct HotKeySettings {
    static let storageKey = "hotKey"
    let store: any PreferenceStore

    public init(store: any PreferenceStore = UserDefaults.standard) {
        self.store = store
    }

    public var combo: KeyCombo {
        get {
            guard let data = store.object(forKey: Self.storageKey) as? Data,
                let stored = try? JSONDecoder().decode(KeyCombo.self, from: data),
                stored.isValidHotKey
            else { return .defaultCombo }
            return stored
        }
        nonmutating set {
            store.set(try? JSONEncoder().encode(newValue), forKey: Self.storageKey)
        }
    }
}
