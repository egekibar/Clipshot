import Foundation
import Testing

@testable import ClipshotCore

@Suite("GitHubReleaseParser")
struct GitHubReleaseParserTests {
    /// The fields Clipshot reads from `GET /repos/{owner}/{repo}/releases/latest`, plus some it ignores.
    func payload(tag: String = "v1.1.0", prerelease: Bool = false, assets: String) -> Data {
        Data(
            """
            {
              "tag_name": "\(tag)",
              "name": "Clipshot \(tag)",
              "draft": false,
              "prerelease": \(prerelease),
              "html_url": "https://github.com/egekibar/Clipshot/releases/tag/\(tag)",
              "body": "\\n- Faster capture\\n",
              "assets": [\(assets)]
            }
            """.utf8)
    }

    func asset(_ name: String, size: Int = 10) -> String {
        """
        {"name": "\(name)", "size": \(size), "content_type": "application/octet-stream",
         "browser_download_url": "https://github.com/egekibar/Clipshot/releases/download/v1.1.0/\(name)"}
        """
    }

    @Test func readsTheReleaseAndItsDmgWithChecksum() throws {
        let json = payload(
            assets: [asset("notes.txt"), asset("Clipshot-1.1.0.dmg", size: 1234), asset("Clipshot-1.1.0.dmg.sha256")]
                .joined(separator: ","))
        let release = try GitHubReleaseParser.parse(json)
        let download = "https://github.com/egekibar/Clipshot/releases/download/v1.1.0/"
        #expect(
            release
                == ReleaseInfo(
                    version: AppVersion(major: 1, minor: 1, patch: 0), tag: "v1.1.0", notes: "- Faster capture",
                    pageURL: URL(string: "https://github.com/egekibar/Clipshot/releases/tag/v1.1.0")!,
                    dmgURL: URL(string: download + "Clipshot-1.1.0.dmg")!, dmgSize: 1234,
                    checksumURL: URL(string: download + "Clipshot-1.1.0.dmg.sha256")!, isPrerelease: false))
    }

    @Test func releaseWithoutADmgHasNothingToInstall() throws {
        let release = try GitHubReleaseParser.parse(payload(assets: asset("Clipshot.zip")))
        #expect(release.dmgURL == nil)
        #expect(release.checksumURL == nil)
    }

    /// A checksum belongs to the DMG only when it is named after it.
    @Test func checksumOfAnotherFileIsNotUsed() throws {
        let json = payload(assets: [asset("Clipshot-1.1.0.dmg"), asset("Other.dmg.sha256")].joined(separator: ","))
        #expect(try GitHubReleaseParser.parse(json).checksumURL == nil)
    }

    @Test func prereleaseComesFromTheFlagOrTheTag() throws {
        #expect(try GitHubReleaseParser.parse(payload(prerelease: true, assets: "")).isPrerelease)
        #expect(try GitHubReleaseParser.parse(payload(tag: "v1.2.0-beta.1", assets: "")).isPrerelease)
        #expect(try !GitHubReleaseParser.parse(payload(assets: "")).isPrerelease)
    }

    @Test func unreadableAnswersThrow() {
        #expect(throws: UpdateError.unreadableRelease) { try GitHubReleaseParser.parse(Data("<html>".utf8)) }
        #expect(throws: UpdateError.unreadableRelease) {
            try GitHubReleaseParser.parse(payload(tag: "nightly", assets: ""))
        }
    }

    /// `shasum -a 256` writes "<hash>  <file>".
    @Test func checksumIsTheFirstWordOfAShasumLine() {
        let hash = String(repeating: "Ab", count: 32)
        #expect(GitHubReleaseParser.checksum(from: "\(hash)  Clipshot-1.1.0.dmg\n") == hash.lowercased())
        #expect(GitHubReleaseParser.checksum(from: "not-a-hash  file") == nil)
        #expect(GitHubReleaseParser.checksum(from: String(repeating: "a", count: 63)) == nil)
        #expect(GitHubReleaseParser.checksum(from: "") == nil)
    }
}
