import Testing
@testable import NidoCore

struct AppVersionTests {
    @Test
    func formatsVersionBuildAndRevision() throws {
        let version = try #require(AppVersion(
            infoDictionary: [
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": "48",
            ],
            metadataDictionary: [
                "GitRevision": "abc1234",
                "GitDirty": false,
            ]
        ))

        #expect(version.displayString == "0.1.0 (48) · abc1234")
    }

    @Test
    func fallsBackToVersionAndBuildWithoutRevision() throws {
        let version = try #require(AppVersion(
            infoDictionary: [
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": "48",
            ],
            metadataDictionary: [:]
        ))

        #expect(version.displayString == "0.1.0 (48)")
    }

    @Test
    func doesNotInventIdentityWhenRequiredBundleKeysAreMissing() {
        #expect(AppVersion(infoDictionary: [:], metadataDictionary: [:]) == nil)
        #expect(AppVersion(
            infoDictionary: ["CFBundleShortVersionString": "0.1.0"],
            metadataDictionary: [:]
        ) == nil)
    }
}
