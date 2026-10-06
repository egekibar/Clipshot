import Foundation

/// When to ask GitHub, and which releases to install.
public enum UpdateCheckPolicy {
    /// Automatic checks run at most every six hours: an update lands the same day, far below GitHub's
    /// unauthenticated limit of 60 requests an hour.
    public static let interval: TimeInterval = 6 * 60 * 60

    /// A last check in the future (the clock went back) counts as due, otherwise checks would stop until the
    /// clock caught up.
    public static func isDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        let elapsed = now.timeIntervalSince(lastCheck)
        return elapsed < 0 || elapsed >= interval
    }

    /// Only a newer, stable release is installed; prereleases never reach Clipshot automatically.
    public static func shouldInstall(_ release: ReleaseInfo, current: AppVersion) -> Bool {
        !release.isPrerelease && release.version > current
    }
}
