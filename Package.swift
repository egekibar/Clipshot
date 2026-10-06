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
        // Marks on a screenshot: model, undo, geometry, keys and rendering. CoreGraphics only, fully testable.
        .target(name: "ClipshotMarkup", swiftSettings: serviceSettings),
        // The in-place marking panel: canvas, toolbar, keyboard (AppKit).
        .target(name: "ClipshotMarkupUI", dependencies: ["ClipshotMarkup"], swiftSettings: appSettings),
        // Updates from GitHub Releases: release feed, DMG download/verify/stage, post-exit bundle swap, auto-updater.
        .target(name: "ClipshotUpdater", dependencies: ["ClipshotCore"], swiftSettings: serviceSettings),
        // Shared by the test targets only (never linked into the app).
        .target(name: "ClipshotTestSupport", dependencies: ["ClipshotCore"], swiftSettings: serviceSettings),
        // AppKit composition root: menu bar item, shortcut recorder, alerts. No logic worth a test lives here.
        .executableTarget(
            name: "ClipshotApp",
            dependencies: ["ClipshotCore", "ClipshotHotKey", "ClipshotUpdater", "ClipshotMarkup", "ClipshotMarkupUI"],
            swiftSettings: appSettings),
        .testTarget(
            name: "ClipshotCoreTests", dependencies: ["ClipshotCore", "ClipshotTestSupport"],
            swiftSettings: serviceSettings),
        .testTarget(
            name: "ClipshotHotKeyTests", dependencies: ["ClipshotHotKey", "ClipshotCore", "ClipshotTestSupport"],
            swiftSettings: serviceSettings),
        .testTarget(name: "ClipshotMarkupTests", dependencies: ["ClipshotMarkup"], swiftSettings: serviceSettings),
        .testTarget(
            name: "ClipshotMarkupUITests", dependencies: ["ClipshotMarkupUI", "ClipshotMarkup"],
            swiftSettings: appSettings),
        .testTarget(
            name: "ClipshotUpdaterTests", dependencies: ["ClipshotUpdater", "ClipshotCore", "ClipshotTestSupport"],
            swiftSettings: serviceSettings),
    ],
    swiftLanguageModes: [.v6]
)
