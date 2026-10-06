import ClipshotCore
import Foundation

/// Keeps Clipshot on the newest GitHub release without asking: when a check is due it asks the feed, downloads and
/// verifies a newer stable release, and hands the staged app to `install` (swap helper + quit) once Clipshot is idle.
///
/// Everything that touches the system comes in from outside, so the rules are testable: the feed, the installer, the
/// clock, "is a selection or the shortcut recorder open?" and the install step itself.
@MainActor
public final class AutoUpdater {
    public enum Phase: Equatable, Sendable {
        case idle
        case checking
        case downloading(AppVersion)
        /// Downloaded and verified; installs as soon as Clipshot is idle.
        case readyToInstall(AppVersion)
        /// The swap helper is running and Clipshot is quitting.
        case installing(AppVersion)
    }

    public enum CheckResult: Equatable, Sendable {
        case upToDate(AppVersion)
        /// A newer release is being installed, or waits for Clipshot to be idle.
        case updating(AppVersion)
        /// A check or download is already running.
        case busy
        case failed(UpdateError)
    }

    public private(set) var phase: Phase = .idle
    public let current: AppVersion

    private let feed: any ReleaseFeed
    private let installer: any UpdateInstaller
    private let preferences: AppPreferences
    private let now: () -> Date
    private let isIdle: () -> Bool
    private let install: (URL) throws -> Void
    private var staged: URL?

    public init(
        current: AppVersion, feed: any ReleaseFeed, installer: any UpdateInstaller, preferences: AppPreferences,
        now: @escaping () -> Date = Date.init, isIdle: @escaping () -> Bool, install: @escaping (URL) throws -> Void
    ) {
        self.current = current
        self.feed = feed
        self.installer = installer
        self.preferences = preferences
        self.now = now
        self.isIdle = isIdle
        self.install = install
    }

    /// The hourly timer: retries a waiting install, otherwise checks when six hours have passed since the last
    /// successful check. nil when there was nothing to do.
    @discardableResult
    public func tick() async -> CheckResult? {
        if case .readyToInstall(let version) = phase {
            installIfIdle()
            return .updating(version)
        }
        guard phase == .idle, UpdateCheckPolicy.isDue(lastCheck: preferences.lastUpdateCheck, now: now()) else {
            return nil
        }
        return await check()
    }

    /// "Güncellemeleri Denetle…": checks now, however recent the last check was.
    public func checkNow() async -> CheckResult {
        if case .readyToInstall(let version) = phase {
            installIfIdle()
            return .updating(version)
        }
        guard phase == .idle else { return .busy }
        return await check()
    }

    /// Call whenever Clipshot may have become idle (a selection ended, the recorder closed).
    public func installIfIdle() {
        guard case .readyToInstall(let version) = phase, let staged, isIdle() else { return }
        phase = .installing(version)
        do {
            try install(staged)
        } catch {
            // Clipshot keeps running on the old version; the next check downloads the release again.
            try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
            self.staged = nil
            phase = .idle
        }
    }

    private func check() async -> CheckResult {
        phase = .checking
        let release: ReleaseInfo
        do {
            release = try await feed.latest()
        } catch {
            // Not recorded as a check: offline or GitHub down, the next hourly tick tries again.
            phase = .idle
            return .failed(Self.updateError(error))
        }
        preferences.lastUpdateCheck = now()
        guard UpdateCheckPolicy.shouldInstall(release, current: current) else {
            phase = .idle
            return .upToDate(current)
        }

        phase = .downloading(release.version)
        do {
            staged = try await installer.prepare(release) { _ in }
        } catch {
            phase = .idle
            return .failed(Self.updateError(error))
        }
        phase = .readyToInstall(release.version)
        installIfIdle()
        return .updating(release.version)
    }

    private static func updateError(_ error: any Error) -> UpdateError {
        error as? UpdateError ?? .network(String(describing: error))
    }
}
