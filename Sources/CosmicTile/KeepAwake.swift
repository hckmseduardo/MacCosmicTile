import Foundation
import IOKit.pwr_mgt

/// A process-scoped assertion; never changes persistent power settings.
@MainActor final class KeepAwake {
    private var assertion: IOPMAssertionID?
    var enabled: Bool { assertion != nil }

    func setEnabled(_ value: Bool) throws {
        guard value != enabled else { return }
        if value {
            var identifier: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "CosmicTile Keep awake" as CFString, &identifier)
            guard result == kIOReturnSuccess else {
                throw NSError(domain: "CosmicTile.KeepAwake", code: Int(result),
                              userInfo: [NSLocalizedDescriptionKey: "Could not keep the display awake."])
            }
            assertion = identifier
        } else if let identifier = assertion {
            let result = IOPMAssertionRelease(identifier)
            guard result == kIOReturnSuccess else {
                throw NSError(domain: "CosmicTile.KeepAwake", code: Int(result))
            }
            assertion = nil
        }
    }
}
