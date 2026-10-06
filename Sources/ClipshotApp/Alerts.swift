import AppKit
import ClipshotCore
import ClipshotHotKey

enum Alerts {
    /// Runs `show` from the main run loop rather than inside the current Task's main-queue job. An alert's modal loop
    /// inside such a job keeps the main queue blocked until it closes, so every ⌘P pressed meanwhile would queue up and
    /// open an alert of its own afterwards; from the run loop those presses arrive while the alert is open and
    /// `CaptureFlow` drops them (measured with a probe, 2026-10-06).
    static func fromRunLoop(_ show: @escaping @MainActor @Sendable () -> Void) {
        RunLoop.main.perform { MainActor.assumeIsolated { show() } }
    }

    /// A menu bar app is activated only to show an alert or the recorder; once nothing of it is left on screen, hiding
    /// it hands the keyboard back to the app the user was in.
    static func yieldFocusIfDone() {
        DispatchQueue.main.async {
            if NSApp.isActive, NSApp.keyWindow == nil { NSApp.hide(nil) }
        }
    }

    static func screenRecordingMissing() {
        let alert = NSAlert()
        alert.messageText = "Ekran Kaydı izni gerekli"
        alert.informativeText = """
            Clipshot'un seçtiğin alanı panoya kopyalayabilmesi için Sistem Ayarları › Gizlilik ve Güvenlik › \
            Ekran Kaydı listesinde Clipshot'u aç. İzin, Clipshot yeniden başlayınca geçerli olur.
            """
        alert.addButton(withTitle: "Sistem Ayarlarını Aç")
        alert.addButton(withTitle: "Yeniden Başlat")
        addCancel("Vazgeç", to: alert)
        switch present(alert) {
        case .alertFirstButtonReturn: ScreenRecordingPermission.openSystemSettings()
        case .alertSecondButtonReturn: Relauncher.relaunch()
        default: break
        }
    }

    static func captureFailed(_ detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Ekran görüntüsü alınamadı"
        alert.informativeText = detail
        present(alert)
    }

    /// Shown at launch when the saved shortcut could not be registered. True: the user wants to pick another.
    static func shortcutUnavailable(_ combo: KeyCombo, error: HotKeyError) -> Bool {
        let alert = NSAlert()
        alert.messageText = "\(combo.label) kısayolu kullanılamıyor"
        alert.informativeText = "\(describe(error)) Başka bir kısayol seçebilirsin."
        alert.addButton(withTitle: "Kısayolu Değiştir…")
        addCancel("Tamam", to: alert)
        return present(alert) == .alertFirstButtonReturn
    }

    /// True: hide it. Says how to get the icon back, since nothing on screen will.
    static func confirmHidingIcon() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Simge menü çubuğundan gizlensin mi?"
        alert.informativeText = """
            Kısayol çalışmaya devam eder. Simgeyi geri getirmek için Clipshot'u Spotlight'tan ya da \
            Uygulamalar klasöründen yeniden aç.
            """
        alert.addButton(withTitle: "Gizle")
        addCancel("Vazgeç", to: alert)
        return present(alert) == .alertFirstButtonReturn
    }

    /// True: delete every kept screenshot.
    static func confirmClearingHistory() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Geçmiş temizlensin mi?"
        alert.informativeText = "Saklanan bütün ekran görüntüleri silinir. Bu geri alınamaz."
        alert.addButton(withTitle: "Temizle").hasDestructiveAction = true
        addCancel("Vazgeç", to: alert)
        return present(alert) == .alertFirstButtonReturn
    }

    static func upToDate(_ version: AppVersion) {
        let alert = NSAlert()
        alert.messageText = "Clipshot güncel"
        alert.informativeText = "\(version) en son sürüm."
        present(alert)
    }

    static func updateFailed(_ error: UpdateError) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Güncelleme denetlenemedi"
        alert.informativeText = error.message
        present(alert)
    }

    static func loginItemFailed(_ error: any Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Girişte açılma ayarlanamadı"
        alert.informativeText = error.localizedDescription
        present(alert)
    }

    static func describe(_ error: HotKeyError) -> String {
        switch error {
        case .registrationFailed(-9878): "Bu kısayol zaten kayıtlı."
        case .registrationFailed(let status): "macOS kısayolu kaydetmedi (hata \(status))."
        }
    }

    /// NSAlert maps Esc only to a button titled "Cancel"; the Turkish one needs the key set by hand.
    private static func addCancel(_ title: String, to alert: NSAlert) {
        alert.addButton(withTitle: title).keyEquivalent = "\u{1b}"
    }

    @discardableResult
    private static func present(_ alert: NSAlert) -> NSApplication.ModalResponse {
        // A menu bar app is never frontmost on its own; without this the alert can open behind the active app.
        NSApp.activate()
        alert.window.level = .floating
        let response = alert.runModal()
        yieldFocusIfDone()
        return response
    }
}
