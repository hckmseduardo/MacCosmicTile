import XCTest
import CoreGraphics
@testable import TileCore
final class PlacementTests: XCTestCase {
    func testNewWindowUsesPreviousFocus() {
        XCTAssertEqual(Placement.anchor(existing: [1, 2], focused: 3, previous: 2), 2)
    }
    func testMissingPreviousFocusFallsBackToLastLeaf() {
        XCTAssertEqual(Placement.anchor(existing: [1, 2], focused: 3, previous: 999), 2)
    }
    func testWideRegionSplitsSideBySide() {
        XCTAssertTrue(Placement.axis(for: CGRect(x: 0, y: 0, width: 1600, height: 900)) == .horizontal)
    }
    func testNarrowRegionSplitsTopBottom() {
        XCTAssertTrue(Placement.axis(for: CGRect(x: 0, y: 0, width: 780, height: 900)) == .vertical)
    }
    func testCrowdedFocusedTileUsesLargerNeighbor() {
        let frames = [1: CGRect(x: 0, y: 0, width: 700, height: 900), 2: CGRect(x: 700, y: 0, width: 700, height: 445), 3: CGRect(x: 700, y: 455, width: 700, height: 445)]
        XCTAssertEqual(Placement.target(frames: frames, preferred: 3, gap: 10), 1)
    }
    func testRoomyFocusedTileKeepsPriority() {
        let frames = [1: CGRect(x: 0, y: 0, width: 700, height: 900), 2: CGRect(x: 700, y: 0, width: 700, height: 900)]
        XCTAssertEqual(Placement.target(frames: frames, preferred: 2, gap: 10), 2)
    }
}
