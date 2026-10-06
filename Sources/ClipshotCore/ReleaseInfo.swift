import Foundation

/// The newest published release, as far as updating needs it.
public struct ReleaseInfo: Hashable, Sendable {
    public var version: AppVersion
    /// The git tag as published ("v1.1.0").
    public var tag: String
    /// The release body (Markdown).
    public var notes: String
    /// The release page, for installing by hand.
    public var pageURL: URL
    /// The `.dmg` asset; nil when the release has none (nothing to install).
    public var dmgURL: URL?
    public var dmgSize: Int64
    /// The `<dmg>.sha256` asset (`shasum -a 256` format); nil when the release has none.
    public var checksumURL: URL?
    public var isPrerelease: Bool

    public init(
        version: AppVersion, tag: String, notes: String, pageURL: URL, dmgURL: URL?, dmgSize: Int64,
        checksumURL: URL?, isPrerelease: Bool
    ) {
        self.version = version
        self.tag = tag
        self.notes = notes
        self.pageURL = pageURL
        self.dmgURL = dmgURL
        self.dmgSize = dmgSize
        self.checksumURL = checksumURL
        self.isPrerelease = isPrerelease
    }
}

/// Why checking for or installing an update failed. `message` is what "Güncellemeleri Denetle…" shows.
public enum UpdateError: Error, Equatable, Sendable {
    /// Offline, DNS, a timeout, a non-2xx answer. The payload is for the log.
    case network(String)
    /// GitHub's unauthenticated limit (60 requests an hour) is used up.
    case rateLimited
    /// The answer was not a release this version can read, or there is no published release yet.
    case unreadableRelease
    case noDownload
    case noChecksum
    case checksumMismatch
    /// Clipshot runs from something other than an `.app` (the bare `swift build` binary).
    case notInstalled
    /// The folder holding Clipshot.app cannot be written.
    case notWritable(String)
    /// The downloaded image does not hold the expected app (wrong bundle id or version, no `.app`).
    case invalidBundle(String)
    /// `hdiutil`, a file operation or the swap helper failed. The payload is for the log.
    case installFailed(String)

    public var message: String {
        switch self {
        case .network: "GitHub'a ulaşılamadı. İnternet bağlantını kontrol edip yeniden dene."
        case .rateLimited: "GitHub şu an çok fazla istek aldı. Bir saat sonra yeniden dene."
        case .unreadableRelease: "Son sürümün bilgisi okunamadı."
        case .noDownload: "Son sürümün indirilebilir bir DMG dosyası yok."
        case .noChecksum: "Son sürümün SHA-256 dosyası yok; güncelleme doğrulanamaz."
        case .checksumMismatch: "Güncelleme doğrulanamadı: indirilen dosyanın SHA-256 değeri tutmuyor."
        case .notInstalled: "Clipshot bir uygulama paketinden çalışmıyor; güncelleme kurulamaz."
        case .notWritable(let path): "\(path) klasörüne yazılamıyor. Güncellemeyi DMG'den elle kurabilirsin."
        case .invalidBundle(let reason): "İndirilen paket beklenen uygulama değil (\(reason))."
        case .installFailed: "Güncelleme kurulamadı."
        }
    }
}

/// Reads GitHub's `GET /repos/{owner}/{repo}/releases/latest` answer and the `.sha256` asset next to the DMG.
public enum GitHubReleaseParser {
    private struct Payload: Decodable {
        struct Asset: Decodable {
            var name: String
            var size: Int64?
            var downloadURL: URL
            enum CodingKeys: String, CodingKey {
                case name, size
                case downloadURL = "browser_download_url"
            }
        }
        var tag: String
        var body: String?
        var pageURL: URL
        var prerelease: Bool?
        var assets: [Asset]?
        enum CodingKeys: String, CodingKey {
            case body, prerelease, assets
            case tag = "tag_name"
            case pageURL = "html_url"
        }
    }

    public static func parse(_ data: Data) throws -> ReleaseInfo {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
            let version = AppVersion(payload.tag)
        else { throw UpdateError.unreadableRelease }
        let assets = payload.assets ?? []
        let dmg = assets.first { $0.name.lowercased().hasSuffix(".dmg") }
        let checksum = dmg.flatMap { dmg in assets.first { $0.name == dmg.name + ".sha256" } }
        return ReleaseInfo(
            version: version,
            tag: payload.tag,
            notes: payload.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            pageURL: payload.pageURL,
            dmgURL: dmg?.downloadURL,
            dmgSize: dmg?.size ?? 0,
            checksumURL: checksum?.downloadURL,
            isPrerelease: payload.prerelease == true || version.isPrerelease)
    }

    /// The lowercase hex digest from a `shasum -a 256` line ("<hash>  <file>"); nil when it is not one.
    public static func checksum(from text: String) -> String? {
        guard let first = text.split(whereSeparator: \.isWhitespace).first else { return nil }
        let hash = first.lowercased()
        guard hash.count == 64, hash.allSatisfy(\.isHexDigit) else { return nil }
        return hash
    }
}
