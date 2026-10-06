import Foundation

/// Where small preferences live: UserDefaults in the app, a dictionary in tests.
public protocol PreferenceStore: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: PreferenceStore {}
