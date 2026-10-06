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

    /// Screenshots are kept three days unless the user picks otherwise in Ayarlar.
    @Test func historyIsKeptThreeDaysByDefault() {
        #expect(AppPreferences(store: store).historyDays == 3)
    }

    /// The stepper offers 1–30 days; anything else (a hand-edited value, say) is pulled back into that range.
    @Test func historyDaysStayBetweenOneAndThirty() {
        let preferences = AppPreferences(store: store)
        preferences.historyDays = 7
        #expect(AppPreferences(store: store).historyDays == 7)
        preferences.historyDays = 0
        #expect(preferences.historyDays == 1)
        store.set(45, forKey: "historyDays")
        #expect(preferences.historyDays == 30)
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
