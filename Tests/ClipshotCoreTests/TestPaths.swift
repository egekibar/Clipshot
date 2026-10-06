import Foundation

enum TestPaths {
    /// Tests/Fixtures: every test target lives in Tests/<Target>/, so two levels up.
    static var fixtures: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // TestPaths.swift
            .deletingLastPathComponent()  // <Target>
            .appendingPathComponent("Fixtures", isDirectory: true)
    }

    static func fixture(_ name: String) -> URL { fixtures.appendingPathComponent(name) }

    /// Unique path under the system temp dir. Nothing is created.
    static func scratchFile(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("clipshot-test-\(UUID().uuidString).\(ext)")
    }
}
