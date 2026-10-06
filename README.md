# Clipshot

⌘P'ye bas, alanı seç: seçtiğin alan dosyaya değil doğrudan panoya gider, ⌘V ile istediğin yere yapıştırırsın.
Menü çubuğunda yaşayan, Dock'ta görünmeyen, kendini GitHub'dan güncelleyen küçük bir macOS uygulaması.

## Kurulum

macOS 26 (Tahoe) ve Apple silicon gerekir.

```bash
brew install --cask egekibar/tap/clipshot
```

Ya da [Releases](https://github.com/egekibar/Clipshot/releases) sayfasından `Clipshot-<sürüm>.dmg`'yi indirip
Clipshot'u Uygulamalar'a sürükle. Uygulama Apple tarafından notarize edilmediği için DMG'den kurulan kopyayı ilk açışta
macOS engeller: Sistem Ayarları › Gizlilik ve Güvenlik › "Yine de Aç". Homebrew bu adımı kendisi halleder.

İlk açılışta macOS **Ekran Kaydı** izni ister: Sistem Ayarları › Gizlilik ve Güvenlik › Ekran Kaydı'nda Clipshot'u
aç, sonra "Çık ve Yeniden Aç"a bas. Güncellemeler aynı sertifikayla imzalandığı için izin sonraki sürümlerde korunur.

## Kullanım

- **⌘P**: artı imleci çıkar, sürükleyerek alan seç. Bıraktığın anda görüntü panodadır ve menü çubuğunda kısa bir ✓ görünür.
- **Space**: pencere seçimine geç. **Esc**: vazgeç.
- Seçimden sonra alan yerinde donar; istersen üzerine işaret koyarsın (aşağıya bak).
- Menü çubuğu simgesi: *Seçili Alanı Kopyala*, *Kısayolu Değiştir…*, *Kısayolu Duraklat*, *Girişte Aç*,
  *Menü Çubuğundan Gizle…*, *Güncellemeleri Denetle…*, *Clipshot'tan Çık*.

### İşaretleme

Seçim biter bitmez görüntü panoya gider ve seçtiğin alan olduğu yerde donar: etrafında ince bir çerçeve, altında
küçük bir araç çubuğu. İşaret koyman gerekmiyorsa başka bir yere tıklayıp devam et; panoda sade görüntü kalır.

| Tuş | Ne yapar |
|---|---|
| `1` `2` `3` `4` | Kutu, Ok, Fosforlu kalem, Serbest kalem (açılışta kırmızı kutu seçili) |
| ↩ ya da ⌘C | İşaretli hali panoya koyar ve kapatır; başka bir yere tıklamak da işaretleri korur |
| ⌘Z ya da ⌫ | Son işareti geri alır |
| Esc | İşaretleri atar; panoda sade görüntü kalır |

Renkler araç çubuğundaki noktalardan seçilir; her araç kendi rengini hatırlar (fosforlu kalem sarı başlar). Panoya
giden görüntü tam Retina çözünürlüğündedir. İşaretlerken ⌘P'ye basarsan işaretler korunur ve yeni seçim başlar.

### ⌘P ve yazdırma

Clipshot açıkken ⌘P her uygulamada ekran görüntüsü alır, yani yazdırma kısayolu çalışmaz. Yazdırman gerekince
menüden *Kısayolu Duraklat*'ı seç. Kalıcı olarak başka bir tuş istersen *Kısayolu Değiştir…* ile yeni bir kombinasyon
kaydet (örneğin ⌃⇧⌘P). Seçimin saklanır; *Varsayılan (⌘P)* düğmesi geri döndürür.

### Girişte açılma

İlk açılıştan itibaren açıktır; menüdeki *Girişte Aç* ile kapatılır. Clipshot bunun için
`~/Library/LaunchAgents/com.egekibar.clipshot.plist` yazar; Sistem Ayarları › Genel › Giriş Öğeleri'nde Clipshot olarak
görünür.

### Menü çubuğundan gizleme

*Menü Çubuğundan Gizle…* simgeyi kaldırır; kısayol çalışmaya devam eder ve girişte de gizli açılır. Simgeyi geri
getirmek için Clipshot'u Spotlight'tan ya da Uygulamalar klasöründen yeniden aç.

### Güncellemeler

Clipshot açılıştan ~10 saniye sonra ve sonra en geç altı saatte bir GitHub'daki son sürüme bakar. Daha yeni bir sürüm
varsa DMG'yi indirir, SHA-256 ile doğrular, seçim ya da kısayol kaydı açık değilken kendini kapatır, yeni sürümle
değiştirir ve yeniden açar; soru sormaz. *Güncellemeleri Denetle…* beklemeden bakar.

## Geliştirme

Gerekenler: Xcode Command Line Tools (`xcode-select --install`). Xcode gerekmez.

| Komut | Ne yapar |
|---|---|
| `make test` | Tüm testler (Swift Testing). `make test FILTER='KeyCombo'` ile süz. |
| `make run` | Release derlemesi, `~/Applications`'a kur, aç |
| `make dmg` | `dist/Clipshot-<sürüm>.dmg` ve `.sha256` |
| `make release VERSION=1.0.1` | Testler, sürüm, imzalı DMG, tag, GitHub release, Homebrew cask |
| `make cert` | Her Mac'te bir kez: kalıcı "Clipshot Dev" imza sertifikası |
| `make reset-tcc` | Ekran Kaydı iznini sıfırla |

**İmza:** Release'ler kalıcı bir sertifikayla imzalanır (`make cert`; Anahtar Zinciri güven onayı ister), böylece
macOS her güncellemeyi aynı uygulama sayar ve Ekran Kaydı izni korunur. Sertifika yoksa yerel derlemeler ad-hoc
imzalanır: çalışır, ama izin o derlemeye bağlıdır. `make release` sertifika olmadan çalışmaz.

**Release:** `make release VERSION=1.0.1 [NOTES=notlar.md]` testleri çalıştırır, `Resources/Info.plist`'teki sürümü
yükseltip commit'ler, imzalı DMG'yi üretir, `v1.0.1` tag'ini push'lar, release'i DMG ve `.sha256` ile yayımlar ve
[egekibar/tap](https://github.com/egekibar/homebrew-tap)'teki cask'ı günceller. Yüklü Clipshot'lar en geç altı saat
içinde kendini günceller.

`scripts/make-icon.sh` simgeyi `scripts/render-icon.swift`'ten yeniden üretir.

## Nasıl çalışır

- **Kısayol:** Carbon `RegisterEventHotKey`. Hiçbir izin istemez (Erişilebilirlik ya da Girdi İzleme yok) ve tuş
  vuruşlarını dinlemez; yalnızca kayıtlı kombinasyon uygulamaya iletilir.
- **Seçim:** `/usr/sbin/screencapture -i -c`. Seçim arayüzü macOS'un kendisi; görüntü ⌃⇧⌘4 ile aynı biçimde panoya
  yazılır, diske dosya yazılmaz.
- **İşaretleme:** Seçim sırasında farenin basıldığı ve bırakıldığı yerler (genel fare izleyicisi, izin istemez) alanın
  ekrandaki yerini verir; görüntü tam orada, Clipshot'u etkinleştirmeyen bir panelde açılır. Ekranda görünen ve panoya
  giden işaretler aynı CoreGraphics koduyla çizilir.
- **İzin:** screencapture, Ekran Kaydı iznini kendisini başlatan uygulamaya sorar. O yüzden izin Clipshot'a verilir ve
  gerçek bir `.app` paketi gerekir.
- **Sonuç:** Esc çıkış kodu 1 ve boş stderr demektir, hata sayılmaz. Kopyalamanın olduğu, panonun `changeCount`
  değerinin değişmesinden anlaşılır.
- **Güncelleme:** `api.github.com/repos/egekibar/Clipshot/releases/latest` → DMG + `.sha256` → `hdiutil` ile salt okunur
  bağla, paket kimliğini ve sürümü kontrol et, kopyala → Clipshot kapanınca ayrı bir `/bin/sh` eski paketi yenisiyle
  değiştirir (başarısız olursa eskisini geri koyar) ve uygulamayı açar.

| Modül | İçerik |
|---|---|
| `ClipshotCore` | Yalnızca Foundation: kısayol modeli, screencapture çalıştırıcısı, yakalama kuralları, sürüm ve release okuma, güncelleme zamanlaması, giriş öğesi, tercihler |
| `ClipshotHotKey` | Carbon kısayol servisi ve kısayolu yöneten denetleyici (duraklat, kaydet, geri yükle) |
| `ClipshotMarkup` | Yalnızca CoreGraphics: işaretler, geri alma, panel yerleşimi, kısayollar, Retina çizimi |
| `ClipshotMarkupUI` | AppKit: işaretleme paneli, tuval, araç çubuğu |
| `ClipshotUpdater` | GitHub release akışı, DMG indirme/doğrulama/hazırlama, paket değiştirme, otomatik güncelleyici |
| `ClipshotApp` | AppKit: menü çubuğu, kısayol kayıt penceresi, uyarılar |

Kısayol servisi, screencapture çağrısı, güncelleyici ve paketleme/sertifika/cask betikleri
[Shotcue](https://github.com/egekibar/Shotcue)'dan uyarlandı.
