import Foundation

/// Small choices that outlive a launch (UserDefaults in the app). The shortcut has its own store, `HotKeySettings`.
public struct AppPreferences {
    enum Key {
        static let menuBarIconHidden = "menuBarIconHidden"
        static let loginItemConfigured = "loginItemConfigured"
        static let lastUpdateCheck = "lastUpdateCheck"
    }

    let store: any PreferenceStore

    public init(store: any PreferenceStore = UserDefaults.standard) {
        self.store = store
    }

    /// "Menü Çubuğundan Gizle": the shortcut keeps working, reopening the app shows the icon again.
    public var isMenuBarIconHidden: Bool {
        get { store.object(forKey: Key.menuBarIconHidden) as? Bool ?? false }
        nonmutating set { store.set(newValue, forKey: Key.menuBarIconHidden) }
    }

    /// Set once the first launch has turned "Girişte Aç" on, so a later "off" is never undone.
    public var hasConfiguredLoginItem: Bool {
        get { store.object(forKey: Key.loginItemConfigured) as? Bool ?? false }
        nonmutating set { store.set(newValue, forKey: Key.loginItemConfigured) }
    }

    public var lastUpdateCheck: Date? {
        get { store.object(forKey: Key.lastUpdateCheck) as? Date }
        nonmutating set { store.set(newValue, forKey: Key.lastUpdateCheck) }
    }
}
