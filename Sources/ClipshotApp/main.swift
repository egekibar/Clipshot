import AppKit

// Menu-bar-only app: Info.plist sets LSUIElement; the policy makes a bare `swift run` behave the same.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
