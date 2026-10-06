import ClipshotTestSupport
import Foundation
import Testing

@testable import ClipshotCore

@Suite("AppPreferences")
struct AppPreferencesTests {
    let store = MemoryPreferenceStore()

    /// A fresh install shows its icon, has not set up the login item yet and has never asked GitHub.
    @Test func freshInstallDefaults() {
        let preferences = AppPreferences(store: store)
        #expect(!preferences.isMenuBarIconHidden)
        #expect(!preferences.hasConfiguredLoginItem)
        #expect(preferences.lastUpdateCheck == nil)
    }

    @Test func choicesSurviveARelaunch() {
        let checked = Date(timeIntervalSince1970: 1_800_000_000)
        let first = AppPreferences(store: store)
        first.isMenuBarIconHidden = true
        first.hasConfiguredLoginItem = true
        first.lastUpdateCheck = checked

        let relaunched = AppPreferences(store: store)
        #expect(relaunched.isMenuBarIconHidden)
        #expect(relaunched.hasConfiguredLoginItem)
        #expect(relaunched.lastUpdateCheck == checked)
    }
}
