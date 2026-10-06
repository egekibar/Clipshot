import Foundation
import Testing

@testable import ClipshotCore

@Suite("UpdateCheckPolicy")
struct UpdateCheckPolicyTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let hour: TimeInterval = 3600

    func release(_ major: Int, _ minor: Int, _ patch: Int, prerelease: Bool = false) -> ReleaseInfo {
        ReleaseInfo(
            version: AppVersion(major: major, minor: minor, patch: patch), tag: "v\(major).\(minor).\(patch)",
            notes: "", pageURL: URL(string: "https://x.test")!, dmgURL: nil, dmgSize: 0, checksumURL: nil,
            isPrerelease: prerelease)
    }

    @Test func firstLaunchChecksAtOnce() {
        #expect(UpdateCheckPolicy.isDue(lastCheck: nil, now: now))
    }

    /// GitHub is asked at most every six hours.
    @Test func checksAgainOnlyAfterSixHours() {
        #expect(!UpdateCheckPolicy.isDue(lastCheck: now - 6 * hour + 1, now: now))
        #expect(UpdateCheckPolicy.isDue(lastCheck: now - 6 * hour, now: now))
    }

    /// A last check in the future (the clock went back) must not stop checks until the clock catches up.
    @Test func lastCheckInTheFutureIsDue() {
        #expect(UpdateCheckPolicy.isDue(lastCheck: now + 48 * hour, now: now))
    }

    @Test func installsOnlyANewerStableRelease() {
        let current = AppVersion(major: 1, minor: 0, patch: 0)
        #expect(UpdateCheckPolicy.shouldInstall(release(1, 0, 1), current: current))
        #expect(!UpdateCheckPolicy.shouldInstall(release(1, 0, 0), current: current))
        #expect(!UpdateCheckPolicy.shouldInstall(release(0, 9, 0), current: current))
        #expect(!UpdateCheckPolicy.shouldInstall(release(1, 1, 0, prerelease: true), current: current))
    }
}
