// swift-tools-version: 6.4
import PackageDescription

let upcoming: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]
let appSettings: [SwiftSetting] = [.defaultIsolation(MainActor.self)] + upcoming
let serviceSettings: [SwiftSetting] = [.defaultIsolation(nil)] + upcoming

let package = Package(
    name: "Clipshot",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Clipshot", targets: ["ClipshotApp"]),
    ],
    targets: [
        // Foundation only: the hotkey model, its storage, the screencapture run and the capture rules.
        .target(name: "ClipshotCore", swiftSettings: serviceSettings),
        // Carbon RegisterEventHotKey: the one global-hotkey API that needs no TCC permission at all.
        .target(name: "ClipshotHotKey", dependencies: ["ClipshotCore"], swiftSettings: serviceSettings),
        // AppKit composition root: menu bar item, shortcut recorder, alerts. No logic worth a test lives here.
        .executableTarget(
            name: "ClipshotApp", dependencies: ["ClipshotCore", "ClipshotHotKey"], swiftSettings: appSettings),
        .testTarget(name: "ClipshotCoreTests", dependencies: ["ClipshotCore"], swiftSettings: serviceSettings),
        .testTarget(
            name: "ClipshotHotKeyTests", dependencies: ["ClipshotHotKey", "ClipshotCore"],
            swiftSettings: serviceSettings),
    ],
    swiftLanguageModes: [.v6]
)
