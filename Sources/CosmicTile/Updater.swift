import AppKit
import TileCore

@MainActor final class Updater {
    static var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.4.2" }
    private let service = UpdateService()
    private var flow = UpdateFlow()
    private var timer: Timer?
    private var candidate: UpdateCandidate?
    private var installation: Task<Void, Never>?
    var onChange: (() -> Void)?
    var beforePrompt: (() -> Void)?
    var automaticChecks: Bool {
        get { UserDefaults.standard.object(forKey: "updates.automatic") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "updates.automatic"); onChange?() }
    }
    var status: String {
        if flow.isDownloading { return "Preparing update…" }
        if flow.isChecking { return "Checking for updates…" }
        if let candidate { return "Update available: \(candidate.tag)…" }
        return "Check for updates…"
    }
    func start() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            self?.check(manual: false)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check(manual: false) }
        }
    }
    func check(manual: Bool) {
        if !manual {
            let last = UserDefaults.standard.double(forKey: "updates.lastCheck")
            guard automaticChecks, Date().timeIntervalSince1970 - last >= 24 * 3600 else { return }
        }
        guard flow.beginCheck() else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "updates.lastCheck")
        onChange?()
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.check(current: Self.currentVersion)
                candidate = result; flow.completeCheck(result); onChange?()
                if !manual && !automaticChecks { flow.finish(); onChange?(); return }
                guard let result else {
                    if manual { showMessage("No compatible update found", "No newer verified package was found for this Mac. Current version: \(Self.currentVersion).") }
                    return
                }
                let ignored = UserDefaults.standard.string(forKey: "updates.ignoredTag")
                if manual || ignored != result.tag { offer(result) }
                else { flow.finish() }
            } catch {
                flow.finish(); onChange?()
                if manual { showMessage("Could not check for updates", error.localizedDescription) }
            }
        }
    }
    func prepareToQuit() -> NSApplication.TerminateReply {
        guard let installation else { return .terminateNow }
        installation.cancel()
        Task {
            await installation.value
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func offer(_ candidate: UpdateCandidate) {
        beforePrompt?()
        let alert = NSAlert()
        alert.messageText = "CosmicTile \(candidate.tag) is available"
        let megabytes = String(format: "%.1f", Double(candidate.size) / 1_048_576)
        alert.informativeText = "Installed: \(Self.currentVersion) · Download: \(megabytes) MB\n\n\(UpdateNotes.summary(candidate.notes))\n\nCosmicTile will verify the download, install it in the same location and reopen."
        alert.addButton(withTitle: "Install and Restart")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Release notes")
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"
        NSApp.activate()
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            _ = flow.respond(approved: false)
            if response == .alertSecondButtonReturn { UserDefaults.standard.set(candidate.tag, forKey: "updates.ignoredTag") }
            if response == .alertThirdButtonReturn { NSWorkspace.shared.open(candidate.releasePage) }
            onChange?(); return
        }
        guard let authorized = flow.respond(approved: true) else { return }
        onChange?()
        installation = Task { [weak self] in
            guard let self else { return }
            let installer = UpdateInstaller(installed: Bundle.main.bundleURL)
            do {
                try installer.begin()
                do {
                    try await service.download(authorized, to: installer.archive)
                    try Task.checkCancellation()
                    try await Task.detached(priority: .userInitiated) {
                        try installer.prepare(for: authorized.tag)
                    }.value
                    try Task.checkCancellation()
                    try installer.startHelper(waitingFor: ProcessInfo.processInfo.processIdentifier)
                } catch {
                    installer.cleanUp()
                    throw error
                }
                installation = nil
                NSApp.terminate(nil)
            } catch {
                installation = nil
                flow.finish(); onChange?()
                if !Task.isCancelled { showMessage("Could not install the update", error.localizedDescription) }
            }
        }
    }
    private func showMessage(_ title: String, _ message: String) {
        beforePrompt?()
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = message
        alert.addButton(withTitle: "OK"); NSApp.activate(); alert.runModal()
    }
}
