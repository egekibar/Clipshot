import Testing

@testable import ClipshotCore

@Suite("AppVersion")
struct AppVersionTests {
    @Test func readsTagsWithOrWithoutV() {
        #expect(AppVersion("v1.2.3") == AppVersion(major: 1, minor: 2, patch: 3))
        #expect(AppVersion("1.2.3") == AppVersion(major: 1, minor: 2, patch: 3))
        #expect(AppVersion("1.2") == AppVersion(major: 1, minor: 2, patch: 0))
        #expect(AppVersion("2") == AppVersion(major: 2, minor: 0, patch: 0))
    }

    @Test(arguments: ["latest", "1.x", "1.2.3.4", "", "v", "1..2", "-1.0", "1.2.٣"])
    func rejectsWhatIsNotAVersion(_ text: String) {
        #expect(AppVersion(text) == nil)
    }

    /// Compared as numbers: 1.10 is newer than 1.9, which a string compare gets wrong.
    @Test func ordersNumerically() {
        #expect(AppVersion(major: 1, minor: 10, patch: 0) > AppVersion(major: 1, minor: 9, patch: 0))
        #expect(AppVersion(major: 2, minor: 0, patch: 0) > AppVersion(major: 1, minor: 99, patch: 99))
        #expect(AppVersion(major: 1, minor: 0, patch: 1) > AppVersion(major: 1, minor: 0, patch: 0))
        #expect(!(AppVersion(major: 1, minor: 0, patch: 0) < AppVersion(major: 1, minor: 0, patch: 0)))
    }

    @Test func prereleaseComesBeforeItsRelease() throws {
        let beta1 = try #require(AppVersion("1.1.0-beta.1"))
        #expect(beta1 == AppVersion(major: 1, minor: 1, patch: 0, prerelease: "beta.1"))
        #expect(beta1 < AppVersion(major: 1, minor: 1, patch: 0))
        #expect(
            AppVersion(major: 1, minor: 1, patch: 0, prerelease: "beta.2")
                < AppVersion(major: 1, minor: 1, patch: 0, prerelease: "beta.10"))
        #expect(beta1.isPrerelease)
        #expect(!AppVersion(major: 1, minor: 1, patch: 0).isPrerelease)
    }

    @Test func describesWithoutTheV() {
        #expect(AppVersion(major: 1, minor: 2, patch: 0).description == "1.2.0")
        #expect(AppVersion(major: 1, minor: 3, patch: 0, prerelease: "rc.1").description == "1.3.0-rc.1")
    }
}
