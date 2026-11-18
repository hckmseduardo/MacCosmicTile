import XCTest
@testable import TileCore

final class UpdateTests: XCTestCase {
    let digestValue = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    func release(_ tag: String = "v0.5.0", arch: String = "arm64", draft: Bool = false, preview: Bool = false, url: String? = nil, digest: String? = nil) -> GitHubRelease {
        let name = "CosmicTile-\(tag)-macOS-\(arch).zip"
        return GitHubRelease(tag: tag, draft: draft, prerelease: preview, notes: "Release notes", assets: [GitHubAsset(name: name, url: url ?? "https://github.com/hckmseduardo/MacCosmicTile/releases/download/\(tag)/\(name)", size: 5, state: "uploaded", digest: digest ?? "sha256:\(digestValue)")])
    }
    func testNumericVersionsAndPrereleasesAreOrdered() {
        XCTAssertTrue(SemanticVersion("0.10.0")! > SemanticVersion("v0.9.9")!)
        XCTAssertTrue(SemanticVersion("1.0.0-beta.10")! > SemanticVersion("1.0.0-beta.2")!)
        XCTAssertTrue(SemanticVersion("1.0.0")! > SemanticVersion("1.0.0-rc.1")!)
        XCTAssertNil(SemanticVersion("v1.0.0.0"))
        XCTAssertNil(SemanticVersion("1.0.0-beta.01"))
        XCTAssertNil(SemanticVersion("1.0.0-beta\n"))
    }
    func testSelectsNewestCompatibleReleaseIncludingPreviews() {
        let result = ReleasePolicy.select([release("v0.9.0", draft: true), release("v0.4.1"), release("v0.5.0-beta.2", preview: true)], current: "0.4.0", architecture: "arm64")
        XCTAssertEqual(result?.tag, "v0.5.0-beta.2")
    }
    func testWrongCPUAndCurrentVersionAreNotOffers() {
        XCTAssertNil(ReleasePolicy.select([release(arch: "x86_64")], current: "0.4.0", architecture: "arm64"))
        XCTAssertNil(ReleasePolicy.select([release("v0.4.0")], current: "0.4.0", architecture: "arm64"))
    }
    func testRejectsForeignOrInsecureDownloadURLs() {
        for url in ["https://example.com/update.zip", "http://github.com/hckmseduardo/MacCosmicTile/releases/download/v0.5.0/CosmicTile-v0.5.0-macOS-arm64.zip", "https://github.com/other/repo/releases/download/v0.5.0/update.zip"] {
            XCTAssertNil(ReleasePolicy.select([release(url: url)], current: "0.4.0", architecture: "arm64"))
        }
    }
    func testRejectsMalformedDigest() {
        XCTAssertNil(ReleasePolicy.select([release(digest: "sha256:123")], current: "0.4.0", architecture: "arm64"))
    }
    func testDecliningDoesNotReturnDownloadWork() {
        let offer = ReleasePolicy.select([release()], current: "0.4.0", architecture: "arm64")!
        var flow = UpdateFlow()
        XCTAssertNil(flow.respond(approved: true))
        XCTAssertTrue(flow.beginCheck())
        flow.completeCheck(offer)
        XCTAssertNil(flow.respond(approved: false))
        XCTAssertFalse(flow.isDownloading)
    }
    func testApprovalIsSingleFlight() {
        let offer = ReleasePolicy.select([release()], current: "0.4.0", architecture: "arm64")!
        var flow = UpdateFlow(); XCTAssertTrue(flow.beginCheck()); flow.completeCheck(offer)
        XCTAssertFalse(flow.beginCheck(), "An offer awaiting consent must not be replaced by another check")
        XCTAssertEqual(flow.respond(approved: true)?.tag, offer.tag)
        XCTAssertNil(flow.respond(approved: true))
        XCTAssertFalse(flow.beginCheck())
        flow.finish(); XCTAssertTrue(flow.beginCheck())
    }
    func testFileVerificationChecksBytesAndDigest() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("hello".utf8).write(to: file)
        try UpdateIntegrity.verify(file, expectedSize: 5, sha256: digestValue)
        XCTAssertThrowsError(try UpdateIntegrity.verify(file, expectedSize: 6, sha256: digestValue))
        XCTAssertThrowsError(try UpdateIntegrity.verify(file, expectedSize: 5, sha256: String(repeating: "0", count: 64)))
    }
    func testReleaseNoteSummaryFitsAConsentDialog() {
        let notes = (1...50).map { "Line \($0)" }.joined(separator: "\n")
        let summary = UpdateNotes.summary(notes)
        XCTAssertLessThanOrEqual(summary.split(separator: "\n").count, 13)
        XCTAssertTrue(summary.hasSuffix("…"))
        XCTAssertLessThanOrEqual(UpdateNotes.summary(String(repeating: "x", count: 5000)).count, 1202)
    }
}
