import Foundation

/// "Girişte Aç" through a per-user LaunchAgent: launchd runs every agent in ~/Library/LaunchAgents at login, and this
/// one opens Clipshot through LaunchServices. `SMAppService.mainApp` is the modern route, but it reports `.notFound`
/// for a bundle that is not Developer ID signed (measured on Shotcue, 2026-09-23), which is how Clipshot is built.
public struct LoginItem {
    /// The agent's launchd label and file name; the bundle identifier, so System Settings can attribute it.
    public let label: String
    /// The installed bundle the agent opens.
    public let appURL: URL
    /// ~/Library/LaunchAgents in the app; a scratch folder in tests.
    public let agentsDirectory: URL

    public init(label: String, appURL: URL, agentsDirectory: URL) {
        self.label = label
        self.appURL = appURL
        self.agentsDirectory = agentsDirectory
    }

    var plistURL: URL { agentsDirectory.appendingPathComponent("\(label).plist") }

    public var isEnabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    /// Writes (or rewrites, after the app moved) the agent. It takes effect at the next login. An agent that is already
    /// up to date is left alone: every launch calls this, and a rewritten agent can make macOS announce it again.
    public func enable() throws {
        let agent: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", appURL.path],
            "RunAtLoad": true,
            // Lets System Settings › Login Items list the agent as Clipshot instead of as `open`.
            "AssociatedBundleIdentifiers": [label],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: agent, format: .xml, options: 0)
        if let existing = try? Data(contentsOf: plistURL), existing == data { return }
        try FileManager.default.createDirectory(at: agentsDirectory, withIntermediateDirectories: true)
        try data.write(to: plistURL, options: .atomic)
    }

    public func disable() throws {
        guard isEnabled else { return }
        try FileManager.default.removeItem(at: plistURL)
    }
}
