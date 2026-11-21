import AppKit
import XCTest
@testable import CosmicTile

@MainActor final class UpdateInstallerTests: XCTestCase {
    func testBeginCreatesPrivateStagingDirectory() throws {
        let (installer, _) = try fixture(createStaging: false)
        defer { cleanUp(installer) }

        try installer.begin()

        let attributes = try FileManager.default.attributesOfItem(atPath: installer.workDirectory.path)
        XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o700)
    }

    func testSecondAttemptPreservesPendingUpdate() throws {
        let (installer, _) = try fixture()
        defer { cleanUp(installer) }

        XCTAssertThrowsError(try installer.begin())

        XCTAssertTrue(FileManager.default.fileExists(atPath: installer.archive.path))
    }

    func testHelperWaitsThenReplacesAndRelaunchesRenamedBundle() async throws {
        let (installer, version) = try fixture()
        defer { cleanUp(installer) }
        try installer.prepare(for: "v\(version)")

        let parent = try startParent()
        defer { if parent.isRunning { parent.terminate() } }
        let helper = try installer.startHelper(waitingFor: parent.processIdentifier)
        defer { if helper.isRunning { helper.terminate() } }
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(helper.isRunning)
        XCTAssertEqual(try versionAt(installer.installed), "0.4.1")
        parent.terminate()

        let helperExited = try await waitFor(seconds: 65) { !helper.isRunning }
        XCTAssertTrue(helperExited, "The installer never finished")
        guard helperExited else { return }
        XCTAssertEqual(helper.terminationStatus, 0)
        XCTAssertEqual(try versionAt(installer.installed), version)
        XCTAssertTrue(isRunning(at: installer.installed))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installer.workDirectory.path))
    }

    func testRelaunchFailureRestoresAndReopensTheOlderBundle() async throws {
        let (installer, version) = try fixture()
        defer { cleanUp(installer) }
        try installer.prepare(for: "v\(version)")

        // Make the candidate a validly signed app whose executable exits before acknowledging startup.
        let executable = installer.replacement.appendingPathComponent("Contents/MacOS/CosmicTile")
        try FileManager.default.removeItem(at: executable)
        let source = installer.workDirectory.appendingPathComponent("exit.swift")
        try Data("import Darwin\nexit(1)\n".utf8).write(to: source)
        try run("/usr/bin/xcrun", ["swiftc", source.path, "-o", executable.path])
        try run("/usr/bin/codesign", ["--force", "--sign", "-", installer.replacement.path])

        let parent = try startParent()
        parent.terminate()
        var reported = ""
        let status = await installer.installAfterExit(of: parent.processIdentifier) { reported = $0 }

        XCTAssertEqual(status, 1)
        XCTAssertTrue(reported.contains("previous version was restored"), reported)
        XCTAssertEqual(try versionAt(installer.installed), "0.4.1")
        XCTAssertTrue(isRunning(at: installer.installed))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installer.workDirectory.path))
    }

    func testWrongReleaseVersionIsRejectedBeforeReplacement() async throws {
        let (installer, _) = try fixture()
        defer { cleanUp(installer) }
        XCTAssertThrowsError(try installer.prepare(for: "v99.0.0"))
        XCTAssertEqual(try versionAt(installer.installed), "0.4.1")
    }

    private func fixture(createStaging: Bool = true) throws -> (UpdateInstaller, String) {
        guard let path = ProcessInfo.processInfo.environment["COSMICTILE_TEST_APP"] else {
            throw XCTSkip("Set COSMICTILE_TEST_APP to the signed bundle built by build-app.sh")
        }
        let app = URL(fileURLWithPath: path, isDirectory: true)
        let version = try versionAt(app)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CosmicTile Update \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let installed = directory.appendingPathComponent("Installed CosmicTile.app", isDirectory: true)
        do {
            try FileManager.default.copyItem(at: app, to: installed)
            let installer = UpdateInstaller(installed: installed)
            let plist = installer.installed.appendingPathComponent("Contents/Info.plist")
            try run("/usr/libexec/PlistBuddy", ["-c", "Set :CFBundleShortVersionString 0.4.1", plist.path])
            try run("/usr/bin/codesign", ["--force", "--sign", "-", installer.installed.path])
            if createStaging {
                try installer.begin()
                try FileManager.default.copyItem(at: app.deletingPathExtension().appendingPathExtension("zip"), to: installer.archive)
            }
            return (installer, version)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    private func versionAt(_ bundle: URL) throws -> String {
        let data = try Data(contentsOf: bundle.appendingPathComponent("Contents/Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap((plist as? [String: Any])?["CFBundleShortVersionString"] as? String)
    }

    private func startParent() throws -> Process {
        let parent = Process()
        parent.executableURL = URL(fileURLWithPath: "/bin/sleep")
        parent.arguments = ["60"]
        try parent.run()
        return parent
    }

    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.executableLoad) }
    }

    private func waitFor(seconds: Int, until condition: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !condition() {
            guard ContinuousClock.now < deadline else { return false }
            try await Task.sleep(for: .milliseconds(100))
        }
        return true
    }

    private func isRunning(at bundle: URL) -> Bool { !runningApps(at: bundle).isEmpty }

    private func runningApps(at bundle: URL) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: UpdateInstaller.bundleID).filter {
            !$0.isTerminated && $0.bundleURL?.resolvingSymlinksInPath().path == bundle.path
        }
    }

    private func cleanUp(_ installer: UpdateInstaller) {
        for running in runningApps(at: installer.installed) { running.forceTerminate() }
        try? FileManager.default.removeItem(at: installer.installed.deletingLastPathComponent())
    }
}
