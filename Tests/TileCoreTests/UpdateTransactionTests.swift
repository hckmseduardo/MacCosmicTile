import XCTest
@testable import TileCore

@MainActor final class UpdateTransactionTests: XCTestCase {
    private enum SwapError: Error { case denied }

    func testCommitKeepsBackupUntilNewAppFinishesStarting() async throws {
        var installed = "old"
        var staged = "new"
        let result = try await UpdateTransaction.apply(swap: { swap(&installed, &staged) }, launch: {
            XCTAssertEqual(installed, "new")
            XCTAssertEqual(staged, "old")
            return .ready
        })
        XCTAssertEqual(result, .installed)
        XCTAssertEqual(installed, "new")
    }

    func testFailedStartRestoresOriginalAtSamePath() async throws {
        var installed = "old"
        var staged = "new"
        let result = try await UpdateTransaction.apply(swap: { swap(&installed, &staged) }, launch: { .failed })
        XCTAssertEqual(result, .restored)
        XCTAssertEqual(installed, "old")
        XCTAssertEqual(staged, "new")
    }

    func testFailedInitialSwapDoesNotStartNewApp() async {
        do {
            _ = try await UpdateTransaction.apply(swap: { throw SwapError.denied }, launch: {
                XCTFail("The new app must not launch when replacement fails")
                return .ready
            })
            XCTFail("Replacement should have failed")
        } catch {
            XCTAssertTrue(error is SwapError)
        }
    }

    func testUnstoppableNewAppKeepsBackup() async {
        var installed = "old"
        var staged = "new"
        do {
            _ = try await UpdateTransaction.apply(swap: { swap(&installed, &staged) }, launch: { .stillRunning })
            XCTFail("Recovery should be reported as blocked")
        } catch {
            XCTAssertTrue(error is UpdateTransaction.RecoveryError)
        }
        XCTAssertEqual(installed, "new")
        XCTAssertEqual(staged, "old")
    }

    func testFailedRollbackReportsThatBackupMustBeKept() async {
        var swapped = false
        do {
            _ = try await UpdateTransaction.apply(swap: {
                guard !swapped else { throw SwapError.denied }
                swapped = true
            }, launch: { .failed })
            XCTFail("Recovery should be reported as blocked")
        } catch {
            XCTAssertTrue(error is UpdateTransaction.RecoveryError)
        }
    }
}
