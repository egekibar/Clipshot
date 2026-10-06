import ClipshotCore
import CryptoKit
import Foundation
import Synchronization
import Testing

@testable import ClipshotUpdater

/// A scratch folder with an "installed" Clipshot.app and a release DMG holding a newer one, both built on the spot.
struct UpdateFixture {
    let root: URL
    let installedApp: URL
    let dmg: URL
    let checksumFile: URL

    static let bundleID = "com.egekibar.clipshot.test"

    init(releaseVersion: String = "1.1.0", releaseBundleID: String = UpdateFixture.bundleID) throws {
        let fm = FileManager.default
        root = fm.temporaryDirectory.appendingPathComponent("clipshot-update-\(UUID().uuidString)", isDirectory: true)
        let installed = root.appendingPathComponent("Applications", isDirectory: true)
        try fm.createDirectory(at: installed, withIntermediateDirectories: true)
        installedApp = try Self.makeApp(in: installed, version: "1.0.0", bundleID: Self.bundleID, marker: "old")

        let source = root.appendingPathComponent("dmg-source", isDirectory: true)
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        _ = try Self.makeApp(in: source, version: releaseVersion, bundleID: releaseBundleID, marker: "new")
        dmg = root.appendingPathComponent("Clipshot-\(releaseVersion).dmg")
        let hdiutil = Process()
        hdiutil.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        hdiutil.arguments = [
            "create", "-quiet", "-srcfolder", source.path, "-volname", "Clipshot", "-format", "UDZO", dmg.path,
        ]
        try hdiutil.run()
        hdiutil.waitUntilExit()
        guard hdiutil.terminationStatus == 0 else { throw UpdateError.installFailed("hdiutil create failed") }

        let sha = SHA256.hash(data: try Data(contentsOf: dmg)).map { String(format: "%02x", $0) }.joined()
        checksumFile = root.appendingPathComponent(dmg.lastPathComponent + ".sha256")
        try "\(sha)  \(dmg.lastPathComponent)\n".write(to: checksumFile, atomically: true, encoding: .utf8)
    }

    static func makeApp(in folder: URL, version: String, bundleID: String, marker: String) throws -> URL {
        let app = folder.appendingPathComponent("Clipshot.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID, "CFBundleShortVersionString": version, "CFBundlePackageType": "APPL",
        ]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try marker.write(to: contents.appendingPathComponent("marker"), atomically: true, encoding: .utf8)
        return app
    }

    func release(version: String = "1.1.0", checksum: URL?? = nil) -> ReleaseInfo {
        ReleaseInfo(
            version: AppVersion(version)!, tag: "v\(version)", notes: "", pageURL: URL(string: "https://x.test")!,
            dmgURL: dmg, dmgSize: 0, checksumURL: checksum ?? checksumFile, isPrerelease: false)
    }

    func installer() -> DMGUpdateInstaller {
        DMGUpdateInstaller(installedApp: installedApp, bundleID: Self.bundleID)
    }

    func cleanUp() { try? FileManager.default.removeItem(at: root) }
}

/// file:// URLs stand in for GitHub's asset links; everything else (hdiutil, SHA-256, ditto) is real.
@Suite("DMGUpdateInstaller", .serialized)
struct DMGUpdateInstallerTests {
    @Test func stagesTheVerifiedAppOnTheInstalledAppsVolume() async throws {
        let fixture = try UpdateFixture()
        defer { fixture.cleanUp() }
        let reported = Mutex<[Double]>([])
        let staged = try await fixture.installer().prepare(fixture.release()) { value in
            reported.withLock { $0.append(value) }
        }
        defer { try? FileManager.default.removeItem(at: staged.deletingLastPathComponent()) }
        #expect(staged.lastPathComponent == "Clipshot.app")
        #expect(staged.deletingLastPathComponent() != fixture.installedApp.deletingLastPathComponent())
        let marker = try String(contentsOf: staged.appendingPathComponent("Contents/marker"), encoding: .utf8)
        #expect(marker == "new")
        #expect(reported.withLock { $0.last } == 1)
        // Nothing is left mounted.
        let mounts = try FileManager.default.contentsOfDirectory(atPath: "/Volumes")
        #expect(!mounts.contains { $0.hasPrefix("clipshot-update-") })
    }

    @Test func refusesAChecksumMismatch() async throws {
        let fixture = try UpdateFixture()
        defer { fixture.cleanUp() }
        try "\(String(repeating: "0", count: 64))  x.dmg".write(
            to: fixture.checksumFile, atomically: true, encoding: .utf8)
        await #expect(throws: UpdateError.checksumMismatch) {
            try await fixture.installer().prepare(fixture.release()) { _ in }
        }
    }

    @Test func refusesAnotherApp() async throws {
        let fixture = try UpdateFixture(releaseBundleID: "com.example.other")
        defer { fixture.cleanUp() }
        await #expect(throws: UpdateError.invalidBundle("paket kimliği farklı")) {
            try await fixture.installer().prepare(fixture.release()) { _ in }
        }
    }

    @Test func refusesAVersionOtherThanTheRelease() async throws {
        let fixture = try UpdateFixture(releaseVersion: "1.0.5")
        defer { fixture.cleanUp() }
        await #expect(throws: UpdateError.invalidBundle("sürüm 1.1.0 değil")) {
            try await fixture.installer().prepare(fixture.release(version: "1.1.0")) { _ in }
        }
    }

    @Test func needsAChecksumAndAnInstalledBundle() async throws {
        let fixture = try UpdateFixture()
        defer { fixture.cleanUp() }
        await #expect(throws: UpdateError.noChecksum) {
            try await fixture.installer().prepare(fixture.release(checksum: .some(nil))) { _ in }
        }
        let bare = DMGUpdateInstaller(
            installedApp: URL(fileURLWithPath: "/usr/local/bin/Clipshot"), bundleID: UpdateFixture.bundleID)
        await #expect(throws: UpdateError.notInstalled) {
            try await bare.prepare(fixture.release()) { _ in }
        }
    }
}

@Suite("BundleSwapper")
struct BundleSwapperTests {
    @Test func swapsOnceTheAppHasQuit() throws {
        let fixture = try UpdateFixture()
        defer { fixture.cleanUp() }
        let staging = fixture.root.appendingPathComponent("staging", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let staged = try UpdateFixture.makeApp(
            in: staging, version: "1.1.0", bundleID: UpdateFixture.bundleID, marker: "new")

        let swap = try BundleSwapper.start(
            waitingFor: exitedPID(), staged: staged, target: fixture.installedApp,
            opener: URL(fileURLWithPath: "/usr/bin/true"))
        swap.waitUntilExit()

        #expect(swap.terminationStatus == 0)
        let marker = try String(
            contentsOf: fixture.installedApp.appendingPathComponent("Contents/marker"), encoding: .utf8)
        #expect(marker == "new")
        #expect(!FileManager.default.fileExists(atPath: staging.path))
    }

    /// A failed update must still leave a working Clipshot behind.
    @Test func keepsTheOldAppWhenTheNewOneIsMissing() throws {
        let fixture = try UpdateFixture()
        defer { fixture.cleanUp() }
        let missing = fixture.root.appendingPathComponent("staging/Clipshot.app")
        let swap = try BundleSwapper.start(
            waitingFor: exitedPID(), staged: missing, target: fixture.installedApp,
            opener: URL(fileURLWithPath: "/usr/bin/true"))
        swap.waitUntilExit()

        #expect(swap.terminationStatus != 0)
        let marker = try String(
            contentsOf: fixture.installedApp.appendingPathComponent("Contents/marker"), encoding: .utf8)
        #expect(marker == "old")
    }

    /// The pid of a process that has already exited.
    func exitedPID() throws -> Int32 {
        let done = Process()
        done.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try done.run()
        done.waitUntilExit()
        return done.processIdentifier
    }
}

/// Against the published release: `CLIPSHOT_LIVE_UPDATE=1 make test FILTER='LiveUpdate'`. Off by default (network).
@Suite("LiveUpdate", .enabled(if: ProcessInfo.processInfo.environment["CLIPSHOT_LIVE_UPDATE"] == "1"))
struct LiveUpdateTests {
    @Test func latestReleaseDownloadsVerifiesAndStages() async throws {
        let release = try await GitHubReleaseFeed(repo: "egekibar/Clipshot").latest()
        #expect(release.dmgURL != nil)
        #expect(release.checksumURL != nil)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("clipshot-live-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let installed = try UpdateFixture.makeApp(
            in: root, version: "0.0.1", bundleID: "com.egekibar.clipshot", marker: "old")
        let staged = try await DMGUpdateInstaller(installedApp: installed, bundleID: "com.egekibar.clipshot")
            .prepare(release) { _ in }
        defer { try? FileManager.default.removeItem(at: staged.deletingLastPathComponent()) }
        let info = NSDictionary(contentsOf: staged.appendingPathComponent("Contents/Info.plist"))
        #expect(info?["CFBundleShortVersionString"] as? String == release.version.description)
        print("live update: \(release.tag) staged at \(staged.path)")
    }
}
