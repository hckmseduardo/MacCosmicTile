/// Swapping the installed and staged bundles keeps the original available until the new app is ready.
@MainActor public enum UpdateTransaction {
    public enum Launch { case ready, failed, stillRunning }
    public enum Outcome: Equatable { case installed, restored }
    public struct RecoveryError: Error {}

    public static func apply(swap: () throws -> Void, launch: () async -> Launch) async throws -> Outcome {
        try swap()
        switch await launch() {
        case .ready:
            return .installed
        case .failed:
            do { try swap() }
            catch { throw RecoveryError() }
            return .restored
        case .stillRunning:
            throw RecoveryError()
        }
    }
}
