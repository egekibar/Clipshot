import Foundation
import Testing

@testable import ClipshotCore

@Suite("AppPreferences")
struct AppPreferencesTests {
    let scratch = ScratchDefaults()

    /// A fresh install shows its icon, has not set up the login item yet and has never asked GitHub.
    @Test func freshInstallDefaults() {
        let preferences = AppPreferences(defaults: scratch.defaults)
        #expect(!preferences.isMenuBarIconHidden)
        #expect(!preferences.hasConfiguredLoginItem)
        #expect(preferences.lastUpdateCheck == nil)
    }

    @Test func choicesSurviveARelaunch() {
        let checked = Date(timeIntervalSince1970: 1_800_000_000)
        let first = AppPreferences(defaults: scratch.defaults)
        first.isMenuBarIconHidden = true
        first.hasConfiguredLoginItem = true
        first.lastUpdateCheck = checked

        let relaunched = AppPreferences(defaults: scratch.defaults)
        #expect(relaunched.isMenuBarIconHidden)
        #expect(relaunched.hasConfiguredLoginItem)
        #expect(relaunched.lastUpdateCheck == checked)
    }
}
