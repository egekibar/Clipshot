import Foundation
import Testing

@testable import ClipshotCore

@Suite("LoginItem")
struct LoginItemTests {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipshot-agents-\(UUID().uuidString)", isDirectory: true)
    let app = URL(fileURLWithPath: "/Users/me/Applications/Clipshot.app")

    func item(app: URL? = nil) -> LoginItem {
        LoginItem(label: "com.egekibar.clipshot", appURL: app ?? self.app, agentsDirectory: folder)
    }

    func agent() throws -> [String: Any] {
        let data = try Data(contentsOf: folder.appendingPathComponent("com.egekibar.clipshot.plist"))
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    /// launchd runs every agent in ~/Library/LaunchAgents at login; this one opens the app through LaunchServices.
    @Test func enablingWritesAnAgentThatOpensTheAppAtLogin() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try item().enable()
        let agent = try agent()
        #expect(agent["Label"] as? String == "com.egekibar.clipshot")
        #expect(agent["ProgramArguments"] as? [String] == ["/usr/bin/open", "/Users/me/Applications/Clipshot.app"])
        #expect(agent["RunAtLoad"] as? Bool == true)
        // Lets System Settings › Login Items list it as Clipshot rather than as `open`.
        #expect(agent["AssociatedBundleIdentifiers"] as? [String] == ["com.egekibar.clipshot"])
        #expect(item().isEnabled)
    }

    @Test func disablingRemovesTheAgent() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try item().enable()
        try item().disable()
        #expect(!item().isEnabled)
        let file = folder.appendingPathComponent("com.egekibar.clipshot.plist")
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func disablingWhatWasNeverEnabledIsFine() throws {
        try item().disable()
        #expect(!item().isEnabled)
    }

    /// Every launch re-enables to follow a moved app; an unchanged agent must stay untouched, or macOS could announce
    /// "Background Items Added" on every launch.
    @Test func enablingAnUpToDateAgentLeavesTheFileAlone() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try item().enable()
        let file = folder.appendingPathComponent("com.egekibar.clipshot.plist")
        let old = Date(timeIntervalSince1970: 1_000_000_000)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: file.path)
        try item().enable()
        let modified = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date
        #expect(modified == old)
    }

    /// The app may have been moved since the agent was written; enabling again points it at the new place.
    @Test func enablingAgainFollowsTheApp() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try item().enable()
        try item(app: URL(fileURLWithPath: "/Applications/Clipshot.app")).enable()
        #expect(try agent()["ProgramArguments"] as? [String] == ["/usr/bin/open", "/Applications/Clipshot.app"])
    }
}
