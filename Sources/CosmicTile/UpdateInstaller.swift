import AppKit
import Darwin
import TileCore

struct UpdateInstaller: Sendable {
    static let bundleID = "dev.cosmictile.mac"
    static let helperArgument = "--apply-staged-update"
    static let readyArgument = "--cosmictile-update-startup"

    let installed: URL
    var workDirectory: URL {
        installed.deletingLastPathComponent().appendingPathComponent(".\(installed.lastPathComponent).update", isDirectory: true)
    }
    private var payload: URL { workDirectory.appendingPathComponent("payload", isDirectory: true) }
    var replacement: URL { payload.appendingPathComponent("CosmicTile.app", isDirectory: true) }
    var archive: URL { workDirectory.appendingPathComponent("release.zip") }
    private var helper: URL { workDirectory.appendingPathComponent("install-update") }
    private var identityFile: URL { workDirectory.appendingPathComponent("original-bundle") }
    private var ready: URL { workDirectory.appendingPathComponent("started") }

    init(installed: URL) {
        self.installed = installed.resolvingSymlinksInPath().standardizedFileURL
    }

    func begin() throws {
        let volume = try? installed.resourceValues(forKeys: [.volumeSupportsSwapRenamingKey])
        guard installed.pathExtension == "app", Bundle(url: installed)?.bundleIdentifier == Self.bundleID,
              volume?.volumeSupportsSwapRenaming != false, let identity = installedBundleIdentity else {
            throw InstallFailure.unsupportedLocation
        }
        do {
            try Data(identity.utf8).write(to: identityFile, options: .withoutOverwriting)
        } catch {
            cleanUp()
            throw error
        }
        guard mkdir(workDirectory.path, 0o700) == 0 else {
            let reason = errno
            if reason == EEXIST { throw InstallFailure.pending(workDirectory.path) }
            throw InstallFailure.unsupportedLocation
        }
    }

    func prepare(for tag: String) throws {
        let files = FileManager.default
        try files.createDirectory(at: payload, withIntermediateDirectories: false)
        // macOS bsdtar rejects traversal through symlinks and parent-directory components by default.
        try run("/usr/bin/tar", ["-xkf", archive.path, "-C", payload.path])
        guard try files.contentsOfDirectory(atPath: payload.path) == ["CosmicTile.app"],
              replacement.resolvingSymlinksInPath().path == replacement.path,
              let bundle = Bundle(url: replacement),
              bundle.bundleIdentifier == Self.bundleID,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let expected = SemanticVersion(tag), SemanticVersion(version) == expected,
              let executable = bundle.executableURL,
              executable.resolvingSymlinksInPath().path == replacement.appendingPathComponent("Contents/MacOS/CosmicTile").path,
              files.isExecutableFile(atPath: executable.path),
              bundle.executableArchitectures?.contains(NSNumber(value: Self.cpuType)) == true else {
            throw InstallFailure.invalidBundle
        }
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", "--all-architectures", replacement.path])
    }

    @discardableResult func startHelper(waitingFor pid: pid_t) throws -> Process {
        guard originalIsInPlace else { throw InstallFailure.appMoved }
        let executable = installed.appendingPathComponent("Contents/MacOS/CosmicTile")
        try FileManager.default.copyItem(at: executable, to: helper)
        let process = Process()
        process.executableURL = helper
        process.arguments = [Self.helperArgument, installed.path, String(pid)]
        try process.run()
        return process
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: workDirectory)
    }

    static func signalStartup() {
        guard CommandLine.arguments.contains(readyArgument), Bundle.main.bundleIdentifier == bundleID else { return }
        let update = Self(installed: Bundle.main.bundleURL)
        guard update.hasPrivateWorkDirectory else { return }
        try? Data().write(to: update.ready, options: .withoutOverwriting)
    }

    @MainActor static func runHelper(arguments: [String]) async -> Int32 {
        guard arguments.count == 4, let parent = pid_t(arguments[3]), parent > 1 else { return 1 }
        let update = Self(installed: URL(fileURLWithPath: arguments[2], isDirectory: true))
        guard URL(fileURLWithPath: arguments[0]).resolvingSymlinksInPath().path == update.helper.path,
              update.hasPrivateWorkDirectory else { return 1 }
        return await update.installAfterExit(of: parent, reportFailure: Self.showFailure)
    }

    @MainActor func installAfterExit(of parent: pid_t, reportFailure: (String) -> Void) async -> Int32 {
        guard await Self.wait(seconds: 30, until: { kill(parent, 0) == -1 && errno == ESRCH }) else {
            cleanUp()
            reportFailure("CosmicTile is still running. Quit the app before trying the update again.")
            return 1
        }
        guard originalIsInPlace, runningAtInstalledPath.isEmpty else {
            cleanUp()
            reportFailure("The app moved or another copy at this location is still running.")
            return 1
        }

        do {
            let result = try await UpdateTransaction.apply(swap: swapBundles, launch: launchReplacement)
            cleanUp()
            if result == .installed { return 0 }
            reportFailure(await reopenAfterFailure("The update did not start. The previous version was restored."))
        } catch is UpdateTransaction.RecoveryError {
            reportFailure("The update could not be restored automatically. The previous app is preserved at:\n\(replacement.path)")
        } catch {
            cleanUp()
            reportFailure(await reopenAfterFailure("CosmicTile could not be replaced. \(error.localizedDescription)"))
        }
        return 1
    }

    func swapBundles() throws {
        // Both directories are on the same volume. RENAME_SWAP never leaves the installed path empty.
        guard renamex_np(installed.path, replacement.path, UInt32(RENAME_SWAP)) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    @MainActor func launchReplacement() async -> UpdateTransaction.Launch {
        guard let app = try? await openInstalled(arguments: [Self.readyArgument]) else {
            return runningAtInstalledPath.isEmpty ? .failed : .stillRunning
        }
        _ = await Self.wait(seconds: 30, until: { app.isTerminated || FileManager.default.fileExists(atPath: ready.path) })
        if app.isTerminated { return .failed }
        if FileManager.default.fileExists(atPath: ready.path) { return .ready }
        app.forceTerminate()
        return await Self.wait(seconds: 5, until: { app.isTerminated }) ? .failed : .stillRunning
    }

    @MainActor private func reopenAfterFailure(_ message: String) async -> String {
        do {
            _ = try await openInstalled(arguments: [])
            return message
        } catch {
            return "\(message) Open CosmicTile again at:\n\(installed.path)"
        }
    }

    @MainActor private func openInstalled(arguments: [String]) async throws -> NSRunningApplication {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true
        configuration.allowsRunningApplicationSubstitution = false
        configuration.arguments = arguments
        return try await NSWorkspace.shared.openApplication(at: installed, configuration: configuration)
    }

    @MainActor private var runningAtInstalledPath: [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).filter {
            !$0.isTerminated && $0.bundleURL?.resolvingSymlinksInPath().path == installed.path
        }
    }

    @MainActor private static func wait(seconds: Int, until condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !condition() {
            guard ContinuousClock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return true
    }

    @MainActor private static func showFailure(_ message: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.activate()
        let alert = NSAlert()
        alert.messageText = "CosmicTile update failed"
        alert.informativeText = message
        alert.runModal()
    }

    private var hasPrivateWorkDirectory: Bool {
        var info = stat()
        return lstat(workDirectory.path, &info) == 0 &&
            (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) &&
            (info.st_mode & 0o077) == 0 && info.st_uid == getuid()
    }

    private var originalIsInPlace: Bool {
        guard let installedBundleIdentity else { return false }
        return (try? String(contentsOf: identityFile, encoding: .utf8)) == installedBundleIdentity
    }

    private var installedBundleIdentity: String? {
        var info = stat()
        guard lstat(installed.path, &info) == 0, (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) else { return nil }
        return "\(info.st_dev):\(info.st_ino)"
    }

    private static var cpuType: Int {
        #if arch(arm64)
        NSBundleExecutableArchitectureARM64
        #else
        NSBundleExecutableArchitectureX86_64
        #endif
    }

    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw InstallFailure.invalidBundle }
    }
}

private enum InstallFailure: LocalizedError {
    case unsupportedLocation, pending(String), invalidBundle, appMoved

    var errorDescription: String? {
        switch self {
        case .unsupportedLocation:
            "CosmicTile needs a writable Applications folder to update. Move it to Applications or ~/Applications, then open it and try again."
        case .pending(let path):
            "An update is in progress or its recovery files are still at \(path)."
        case .invalidBundle:
            "The downloaded archive does not contain a valid signed CosmicTile app for this release and Mac."
        case .appMoved:
            "CosmicTile moved or was replaced while the update was downloading."
        }
    }
}
