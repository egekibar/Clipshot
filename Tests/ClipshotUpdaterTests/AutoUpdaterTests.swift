import ClipshotCore
import ClipshotTestSupport
import Foundation
import Testing

@testable import ClipshotUpdater

/// GitHub as the test arranges it: a fixed answer or error, counting how often it was asked.
actor FakeFeed: ReleaseFeed {
    var answer: Result<ReleaseInfo, UpdateError>
    private(set) var calls = 0

    init(_ answer: Result<ReleaseInfo, UpdateError>) { self.answer = answer }

    func set(_ answer: Result<ReleaseInfo, UpdateError>) { self.answer = answer }

    func latest() async throws -> ReleaseInfo {
        calls += 1
        return try answer.get()
    }
}

/// Download and staging as the test arranges it. With `hold`, `prepare` waits until `release()` is called.
actor FakeInstaller: UpdateInstaller {
    var answer: Result<URL, UpdateError>
    private(set) var prepared: [AppVersion] = []
    private var held: CheckedContinuation<Void, Never>?
    private let hold: Bool

    init(_ answer: Result<URL, UpdateError>, hold: Bool = false) {
        self.answer = answer
        self.hold = hold
    }

    var isHolding: Bool { held != nil }

    func release() {
        held?.resume()
        held = nil
    }

    func prepare(_ release: ReleaseInfo, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        prepared.append(release.version)
        if hold { await withCheckedContinuation { held = $0 } }
        return try answer.get()
    }
}

@MainActor
@Suite("AutoUpdater")
final class AutoUpdaterTests {
    let store = MemoryPreferenceStore()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let staged = URL(fileURLWithPath: "/tmp/staging/Clipshot.app")
    var idle = true
    var installs: [URL] = []
    var installError: UpdateError?

    var preferences: AppPreferences { AppPreferences(store: store) }

    static func release(_ major: Int, _ minor: Int, _ patch: Int, prerelease: Bool = false) -> ReleaseInfo {
        ReleaseInfo(
            version: AppVersion(major: major, minor: minor, patch: patch), tag: "v\(major).\(minor).\(patch)",
            notes: "", pageURL: URL(string: "https://x.test")!,
            dmgURL: URL(string: "https://x.test/Clipshot.dmg"), dmgSize: 1,
            checksumURL: URL(string: "https://x.test/Clipshot.dmg.sha256"), isPrerelease: prerelease)
    }

    func updater(feed: FakeFeed, installer: FakeInstaller) -> AutoUpdater {
        AutoUpdater(
            current: AppVersion(major: 1, minor: 0, patch: 0), feed: feed, installer: installer,
            preferences: preferences, now: { [now] in now }, isIdle: { [unowned self] in idle },
            install: { [unowned self] url in
                if let installError { throw installError }
                installs.append(url)
            })
    }

    @Test func firstTickInstallsANewerReleaseWithoutAsking() async {
        let feed = FakeFeed(.success(Self.release(1, 1, 0)))
        let installer = FakeInstaller(.success(staged))
        let updater = updater(feed: feed, installer: installer)
        await updater.tick()
        #expect(await installer.prepared == [AppVersion(major: 1, minor: 1, patch: 0)])
        #expect(installs == [staged])
        #expect(updater.phase == .installing(AppVersion(major: 1, minor: 1, patch: 0)))
        #expect(preferences.lastUpdateCheck == now)
    }

    @Test func tickBeforeSixHoursAsksNothing() async {
        preferences.lastUpdateCheck = now - 3600
        let feed = FakeFeed(.success(Self.release(1, 1, 0)))
        await updater(feed: feed, installer: FakeInstaller(.success(staged))).tick()
        #expect(await feed.calls == 0)
    }

    @Test func sameVersionIsNotDownloaded() async {
        let installer = FakeInstaller(.success(staged))
        let updater = updater(feed: FakeFeed(.success(Self.release(1, 0, 0))), installer: installer)
        #expect(await updater.checkNow() == .upToDate(AppVersion(major: 1, minor: 0, patch: 0)))
        #expect(await installer.prepared.isEmpty)
        #expect(updater.phase == .idle)
    }

    @Test func prereleaseIsNotDownloaded() async {
        let installer = FakeInstaller(.success(staged))
        let updater = updater(feed: FakeFeed(.success(Self.release(1, 1, 0, prerelease: true))), installer: installer)
        _ = await updater.checkNow()
        #expect(await installer.prepared.isEmpty)
    }

    /// The swap quits Clipshot, so it waits while a selection is on screen or the recorder is open.
    @Test func busyAppGetsTheUpdateOnceIdle() async {
        idle = false
        let updater = updater(
            feed: FakeFeed(.success(Self.release(1, 1, 0))), installer: FakeInstaller(.success(staged)))
        #expect(await updater.checkNow() == .updating(AppVersion(major: 1, minor: 1, patch: 0)))
        #expect(installs.isEmpty)
        #expect(updater.phase == .readyToInstall(AppVersion(major: 1, minor: 1, patch: 0)))

        idle = true
        updater.installIfIdle()
        updater.installIfIdle()
        #expect(installs == [staged])
    }

    @Test func tickRetriesAWaitingInstallWithoutAskingGitHubAgain() async {
        idle = false
        let feed = FakeFeed(.success(Self.release(1, 1, 0)))
        let updater = updater(feed: feed, installer: FakeInstaller(.success(staged)))
        await updater.tick()
        idle = true
        await updater.tick()
        #expect(installs == [staged])
        #expect(await feed.calls == 1)
    }

    /// Offline or GitHub down: the next hourly tick tries again instead of waiting six hours.
    @Test func failedCheckIsRetriedAtTheNextTick() async {
        let feed = FakeFeed(.failure(.network("offline")))
        let updater = updater(feed: feed, installer: FakeInstaller(.success(staged)))
        #expect(await updater.checkNow() == .failed(.network("offline")))
        #expect(preferences.lastUpdateCheck == nil)

        await feed.set(.success(Self.release(1, 1, 0)))
        await updater.tick()
        #expect(await feed.calls == 2)
        #expect(installs == [staged])
    }

    @Test func badDownloadInstallsNothing() async {
        let updater = updater(
            feed: FakeFeed(.success(Self.release(1, 1, 0))), installer: FakeInstaller(.failure(.checksumMismatch)))
        #expect(await updater.checkNow() == .failed(.checksumMismatch))
        #expect(installs.isEmpty)
        #expect(updater.phase == .idle)
    }

    @Test func manualCheckIgnoresTheSixHours() async {
        preferences.lastUpdateCheck = now - 60
        let feed = FakeFeed(.success(Self.release(1, 0, 0)))
        _ = await updater(feed: feed, installer: FakeInstaller(.success(staged))).checkNow()
        #expect(await feed.calls == 1)
    }

    /// A second check during a download would fetch and stage the same release twice.
    @Test func checkDuringADownloadIsBusy() async throws {
        let installer = FakeInstaller(.success(staged), hold: true)
        let updater = updater(feed: FakeFeed(.success(Self.release(1, 1, 0))), installer: installer)
        let first = Task { await updater.checkNow() }
        for _ in 0..<1000 { if await installer.isHolding { break } else { await Task.yield() } }
        try #require(await installer.isHolding, "the first check never started the download")

        #expect(await updater.checkNow() == .busy)
        await installer.release()
        #expect(await first.value == .updating(AppVersion(major: 1, minor: 1, patch: 0)))
    }

    /// If the swap helper cannot start, Clipshot keeps running and a later check tries again.
    @Test func failedInstallLetsALaterCheckTryAgain() async {
        installError = .installFailed("sh: no such file")
        let installer = FakeInstaller(.success(staged))
        let updater = updater(feed: FakeFeed(.success(Self.release(1, 1, 0))), installer: installer)
        _ = await updater.checkNow()
        #expect(updater.phase == .idle)

        installError = nil
        _ = await updater.checkNow()
        #expect(installs == [staged])
        #expect(await installer.prepared.count == 2)
    }
}
