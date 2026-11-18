import XCTest
import CoreGraphics
@testable import TileCore

final class MonitorTests: XCTestCase {
    func testTogglingSecondMonitorPreservesFirst() {
        var state = MonitorTiling()
        state.toggle("primary"); state.toggle("secondary")
        state.toggle("secondary")
        XCTAssertTrue(state.isEnabled("primary"))
        XCTAssertFalse(state.isEnabled("secondary"))
    }
    func testToggleAllEnablesMissingScreensThenDisablesAll() {
        var state = MonitorTiling()
        state.toggle("a")
        state.toggleAll(connected: ["a", "b"])
        XCTAssertEqual(state.active, ["a", "b"])
        state.toggleAll(connected: ["a", "b"])
        XCTAssertTrue(state.active.isEmpty)
    }
    func testDisconnectDropsOnlyRemovedMonitor() {
        var state = MonitorTiling()
        state.toggleAll(connected: ["a", "b"])
        state.reconcile(connected: ["b", "c"])
        XCTAssertEqual(state.active, ["b"])
        XCTAssertFalse(state.isEnabled("c"))
    }
    func testSecondaryReservesMenuBarEvenWhenVisibleFrameIsFullScreen() {
        let frame = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let usable = ScreenGeometry.usableFrame(screen: frame, visible: frame, desktopTop: 1080, menuBarHeight: 30)
        XCTAssertEqual(usable, CGRect(x: 1920, y: 30, width: 1920, height: 1050))
    }
    func testDisplayAbovePrimaryConvertsToNegativeY() {
        let screen = CGRect(x: -800, y: 1080, width: 1600, height: 900)
        let usable = ScreenGeometry.usableFrame(screen: screen, visible: screen, desktopTop: 1080, menuBarHeight: 30)
        XCTAssertEqual(usable, CGRect(x: -800, y: -870, width: 1600, height: 870))
    }
    func testRestoreClampsOldWindowIntoRemainingScreen() {
        let result = ScreenGeometry.clamped(CGRect(x: 2500, y: -400, width: 2000, height: 1200), to: CGRect(x: 0, y: 30, width: 1920, height: 1000))
        XCTAssertEqual(result, CGRect(x: 0, y: 30, width: 1920, height: 1000))
    }
    func testOutlineConvertsQuartzToAppKitCoordinates() {
        XCTAssertEqual(ScreenGeometry.appKitFrame(CGRect(x: 1920, y: 40, width: 800, height: 600), desktopTop: 1080), CGRect(x: 1920, y: 440, width: 800, height: 600))
    }
}
