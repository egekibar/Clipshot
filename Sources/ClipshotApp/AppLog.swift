import os

/// `log show --predicate 'subsystem == "com.egekibar.clipshot"' --last 10m`
enum AppLog {
    static let app = Logger(subsystem: "com.egekibar.clipshot", category: "app")
}
