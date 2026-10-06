# Clipshot

⌘P'ye bas, alanı seç: seçtiğin alan dosyaya değil doğrudan panoya gider, ⌘V ile istediğin yere yapıştırırsın.
Menü çubuğunda yaşayan, Dock'ta görünmeyen küçük bir macOS uygulaması.

## Kurulum

Gerekenler: macOS 26+ ve Xcode Command Line Tools (`xcode-select --install`). Xcode gerekmez.

```bash
make run
```

Release derlemesini alır, `dist/Clipshot.app`'i paketler, `~/Applications`'a kurar ve açar.

İlk açılışta macOS **Ekran Kaydı** izni ister: Sistem Ayarları › Gizlilik ve Güvenlik › Ekran Kaydı'nda
Clipshot'u aç, sonra "Çık ve Yeniden Aç"a bas. İzin, uygulama yeniden başlayınca geçerli olur.

## Kullanım

- **⌘P**: artı imleci çıkar, sürükleyerek alan seç. Bıraktığın anda görüntü panodadır ve menü çubuğunda kısa bir ✓ görünür.
- **Space**: pencere seçimine geç. **Esc**: vazgeç.
- Menü çubuğu simgesi: *Seçili Alanı Kopyala*, *Kısayolu Değiştir…*, *Kısayolu Duraklat*, *Clipshot'tan Çık*.

### ⌘P ve yazdırma

Clipshot açıkken ⌘P her uygulamada ekran görüntüsü alır, yani yazdırma kısayolu çalışmaz. Yazdırman gerekince
menüden *Kısayolu Duraklat*'ı seç. Kalıcı olarak başka bir tuş istersen *Kısayolu Değiştir…* ile yeni bir kombinasyon
kaydet (örneğin ⌃⇧⌘P). Seçimin saklanır; *Varsayılan (⌘P)* düğmesi geri döndürür.

### Girişte başlatma

Sistem Ayarları › Genel › Giriş Öğeleri › "Girişte Aç" listesine `~/Applications/Clipshot.app`'i ekle.

## Geliştirme

| Komut | Ne yapar |
|---|---|
| `make test` | Tüm testler (Swift Testing). `make test FILTER='KeyCombo'` ile süz. |
| `make bundle` | `dist/Clipshot.app` |
| `make run` | Paketle, `~/Applications`'a kur, aç |
| `make cert` | İsteğe bağlı: kalıcı "Clipshot Dev" imza sertifikası (aşağıya bak) |
| `make reset-tcc` | Ekran Kaydı iznini sıfırla |

**İmza ve izin:** Anahtar Zinciri'nde imza kimliği yoksa paket ad-hoc imzalanır. Çalışır, ama Ekran Kaydı izni o
derlemeye bağlıdır: yeniden derleyip kurunca macOS izni tekrar ister. `make cert` bir kez çalıştırılınca (Anahtar
Zinciri güven onayı ister) imza sabit kalır ve izin derlemeler arasında korunur.

`scripts/make-icon.sh` simgeyi `scripts/render-icon.swift`'ten yeniden üretir.

## Nasıl çalışır

- **Kısayol:** Carbon `RegisterEventHotKey`. Hiçbir izin istemez (Erişilebilirlik ya da Girdi İzleme yok) ve tuş
  vuruşlarını dinlemez; yalnızca kayıtlı kombinasyon uygulamaya iletilir.
- **Seçim:** `/usr/sbin/screencapture -i -c`. Seçim arayüzü macOS'un kendisi; görüntü ⌃⇧⌘4 ile aynı biçimde panoya
  yazılır, diske dosya yazılmaz.
- **İzin:** screencapture, Ekran Kaydı iznini kendisini başlatan uygulamaya sorar. O yüzden izin Clipshot'a verilir ve
  gerçek bir `.app` paketi gerekir.
- **Sonuç:** Esc çıkış kodu 1 ve boş stderr demektir, hata sayılmaz. Kopyalamanın olduğu, panonun `changeCount`
  değerinin değişmesinden anlaşılır.

| Modül | İçerik |
|---|---|
| `ClipshotCore` | Yalnızca Foundation: kısayol modeli ve saklanması, screencapture çalıştırıcısı, yakalama kuralları |
| `ClipshotHotKey` | Carbon kısayol servisi ve kısayolu yöneten denetleyici (duraklat, kaydet, geri yükle) |
| `ClipshotApp` | AppKit: menü çubuğu, kısayol kayıt penceresi, uyarılar |

Kısayol servisi, screencapture çağrısı ve paketleme/sertifika betikleri
[Shotcue](https://github.com/egekibar/Shotcue)'dan uyarlandı.
