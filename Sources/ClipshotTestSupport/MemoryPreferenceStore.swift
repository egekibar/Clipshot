import ClipshotCore

/// Preferences kept in memory, so tests never write to ~/Library/Preferences. (A throwaway UserDefaults suite would:
/// cfprefsd writes an empty plist for it even after `removePersistentDomain`, measured 2026-10-06.)
public final class MemoryPreferenceStore: PreferenceStore {
    private var values: [String: Any] = [:]

    public init() {}

    public func object(forKey defaultName: String) -> Any? { values[defaultName] }

    public func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
}
