import XCTest
@testable import TileCore
final class LayoutTests: XCTestCase {
    func testSplitUsesGapAndFillsMonitor() {
        let tree = Layout.split(.horizontal, 0.5, .leaf(1), .leaf(2))
        let frames = tree.frames(in: CGRect(x: -1200, y: 40, width: 1200, height: 800), gap: 10)
        XCTAssertEqual(frames[1], CGRect(x: -1200, y: 40, width: 595, height: 800))
        XCTAssertEqual(frames[2], CGRect(x: -595, y: 40, width: 595, height: 800))
    }
    func testRemovalCollapsesParent() {
        let tree = Layout.split(.vertical, 0.5, .leaf(1), .leaf(2))
        XCTAssertEqual(tree.removing(1)?.ids, [2])
        XCTAssertNil(Layout.leaf(1).removing(1))
    }
    func testResizeUsesParentOfFocusedLeaf() {
        let tree = Layout.split(.horizontal, 0.5, .leaf(1), .split(.vertical, 0.5, .leaf(2), .leaf(3)))
        let frames = tree.resizing(3, delta: 0.1).frames(in: CGRect(x: 0, y: 0, width: 1000, height: 1000), gap: 0)
        XCTAssertEqual(frames[1]?.width, 500)
        XCTAssertEqual(frames[3]?.height, 600)
    }
    func testInsertionTargetsFocusedWindow() {
        let tree = Layout.split(.horizontal, 0.5, .leaf(1), .leaf(2)).inserting(3, beside: 2, axis: .vertical)
        let frames = tree.frames(in: CGRect(x: 0, y: 0, width: 1000, height: 800), gap: 0)
        XCTAssertEqual(frames[1]?.height, 800)
        XCTAssertEqual(frames[3], CGRect(x: 500, y: 400, width: 500, height: 400))
    }
    func testSwapKeepsGeometry() {
        let tree = Layout.split(.horizontal, 0.3, .leaf(1), .leaf(2))
        let area = CGRect(x: 0, y: 0, width: 1000, height: 800)
        XCTAssertEqual(tree.frames(in: area, gap: 10)[1], tree.swapping(1, 2).frames(in: area, gap: 10)[2])
    }
    func testNewFocusedWindowStillEntersLayout() {
        let tree = Layout.split(.horizontal, 0.5, .leaf(1), .leaf(2))
        let result = tree.inserting(3, beside: 3, axis: .vertical)
        XCTAssertEqual(Set(result.ids), Set([1, 2, 3]))
    }
    func testUnknownFocusStillInsertsExactlyOnce() {
        let tree = Layout.split(.horizontal, 0.5, .leaf(1), .leaf(2))
        let result = tree.inserting(3, beside: 999, axis: .vertical)
        XCTAssertEqual(result.ids.count, 3)
        XCTAssertEqual(result.ids.filter { $0 == 3 }.count, 1)
    }
    func testDirectionalResizeFindsMatchingAncestor() {
        let tree = Layout.split(.horizontal, 0.5, .leaf(1), .split(.vertical, 0.5, .leaf(2), .leaf(3)))
        let frames = tree.resizing(3, axis: .horizontal, delta: 0.1).frames(in: CGRect(x: 0, y: 0, width: 1000, height: 800), gap: 0)
        XCTAssertEqual(frames[3]?.width, 600)
        XCTAssertEqual(frames[3]?.height, 400)
    }
    func testRotateChangesOnlyImmediateGroup() {
        let tree = Layout.split(.horizontal, 0.5, .leaf(1), .split(.vertical, 0.5, .leaf(2), .leaf(3)))
        let frames = tree.rotating(3).frames(in: CGRect(x: 0, y: 0, width: 1000, height: 800), gap: 0)
        XCTAssertEqual(frames[1]?.width, 500)
        XCTAssertEqual(frames[3]?.width, 250)
        XCTAssertEqual(frames[3]?.height, 800)
    }
}
