import XCTest
@testable import CosmicTile

final class KeepAwakeTests: XCTestCase {
    @MainActor func testNativeAssertionCanBeEnabledAndReleased() throws {
        let awake = KeepAwake()
        XCTAssertFalse(awake.enabled)
        try awake.setEnabled(true)
        XCTAssertTrue(awake.enabled)
        try awake.setEnabled(true)
        try awake.setEnabled(false)
        XCTAssertFalse(awake.enabled)
    }
}
