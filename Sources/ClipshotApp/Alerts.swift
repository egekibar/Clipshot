import AppKit
import ClipshotCore
import ClipshotHotKey

enum Alerts {
    static func screenRecordingMissing() {
        let alert = NSAlert()
        alert.messageText = "Ekran Kaydı izni gerekli"
        alert.informativeText = """
            Clipshot'un seçtiğin alanı panoya kopyalayabilmesi için Sistem Ayarları › Gizlilik ve Güvenlik › \
            Ekran Kaydı listesinde Clipshot'u aç. İzin, Clipshot yeniden başlayınca geçerli olur.
            """
        alert.addButton(withTitle: "Sistem Ayarlarını Aç")
        alert.addButton(withTitle: "Yeniden Başlat")
        alert.addButton(withTitle: "Vazgeç")
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
        alert.addButton(withTitle: "Tamam")
        return present(alert) == .alertFirstButtonReturn
    }

    static func describe(_ error: HotKeyError) -> String {
        switch error {
        case .registrationFailed(-9878): "Bu kısayol zaten kayıtlı."
        case .registrationFailed(let status): "macOS kısayolu kaydetmedi (hata \(status))."
        }
    }

    @discardableResult
    private static func present(_ alert: NSAlert) -> NSApplication.ModalResponse {
        // A menu bar app is never frontmost on its own; without this the alert can open behind the active app.
        NSApp.activate()
        alert.window.level = .floating
        return alert.runModal()
    }
}
