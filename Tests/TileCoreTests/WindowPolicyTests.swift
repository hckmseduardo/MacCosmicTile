import XCTest
@testable import TileCore
final class WindowPolicyTests: XCTestCase {
    func testStandardResizableDocumentIsEligible() {
        XCTAssertTrue(WindowPolicy.allows(role: "AXWindow", subrole: "AXStandardWindow", modal: false, resizable: true))
    }
    func testModalSavePanelIsNotEligibleEvenWithStandardSubrole() {
        XCTAssertFalse(WindowPolicy.allows(role: "AXWindow", subrole: "AXStandardWindow", modal: true, resizable: true))
    }
    func testSheetIsNeverTiled() {
        XCTAssertFalse(WindowPolicy.allows(role: "AXSheet", subrole: "AXStandardWindow", modal: false, resizable: true))
    }
    func testDialogAndFloatingAuxiliaryAreExcluded() {
        for subrole in ["AXDialog", "AXSystemDialog", "AXFloatingWindow", "AXUnknown"] {
            XCTAssertFalse(WindowPolicy.allows(role: "AXWindow", subrole: subrole, modal: false, resizable: true))
        }
    }
    func testFixedSizeAuxiliaryWindowIsExcluded() {
        XCTAssertFalse(WindowPolicy.allows(role: "AXWindow", subrole: "AXStandardWindow", modal: false, resizable: false))
    }
}
