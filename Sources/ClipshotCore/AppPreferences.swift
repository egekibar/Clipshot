import Foundation

/// Small choices that outlive a launch (UserDefaults). The shortcut has its own store, `HotKeySettings`.
public struct AppPreferences {
    enum Key {
        static let menuBarIconHidden = "menuBarIconHidden"
        static let loginItemConfigured = "loginItemConfigured"
        static let lastUpdateCheck = "lastUpdateCheck"
    }

    let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// "Menü Çubuğundan Gizle": the shortcut keeps working, reopening the app shows the icon again.
    public var isMenuBarIconHidden: Bool {
        get { defaults.bool(forKey: Key.menuBarIconHidden) }
        nonmutating set { defaults.set(newValue, forKey: Key.menuBarIconHidden) }
    }

    /// Set once the first launch has turned "Girişte Aç" on, so a later "off" is never undone.
    public var hasConfiguredLoginItem: Bool {
        get { defaults.bool(forKey: Key.loginItemConfigured) }
        nonmutating set { defaults.set(newValue, forKey: Key.loginItemConfigured) }
    }

    public var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Key.lastUpdateCheck) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Key.lastUpdateCheck) }
    }
}
