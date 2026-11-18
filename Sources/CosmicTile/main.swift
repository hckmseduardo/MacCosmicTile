import AppKit
import Carbon
import Darwin

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let controller = Controller()
    let updater = Updater()
    let hotkeys = Hotkeys()
    var status: NSStatusItem!
    var resizeHint: NSPanel?
    var preferences: Preferences?
    var resizeKeys: [UInt32] = []
    let popover = NSPopover()
    var quickControls: QuickControls!
    var popoverKeyMonitor: Any?
    var commandTarget: AXUIElement?
    var terminationSources: [DispatchSourceSignal] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSApp.applicationIconImage = BrandAssets.image("AppIcon")
        status.button?.image = BrandAssets.statusImage()
        status.button?.imagePosition = .imageLeading
        status.button?.setAccessibilityLabel("CosmicTile")
        status.button?.title = ""
        status.button?.toolTip = "CosmicTile · Control + Option + T para ativar"
        status.button?.target = self; status.button?.action = #selector(togglePopover)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        quickControls = QuickControls(controller: controller, updater: updater)
        quickControls.checkForUpdates = { [weak self] in
            self?.popover.performClose(nil); self?.updater.check(manual: true)
        }
        updater.beforePrompt = { [weak self] in
            guard let controller = self?.controller, controller.resizeMode else { return }
            controller.resizeMode = false; controller.onResizeMode?(false)
        }
        updater.onChange = { [weak self] in
            guard let self else { return }
            if popover.isShown { quickControls.refresh() }
        }
        updater.start()
        quickControls.dismiss = { [weak self] in self?.popover.performClose(nil) }
        quickControls.settings = { [weak self] in self?.showPreferences() }
        quickControls.executeWindowCommand = { [weak self] operation in
            guard let self else { return }
            let target = commandTarget
            popover.performClose(nil)
            controller.commandWindow = target
            if let target { Accessibility.focus(target) }
            operation(); controller.commandWindow = nil
        }
        popover.contentViewController = quickControls; popover.behavior = .transient; popover.delegate = self
        for number in [SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { Task { @MainActor in NSApp.terminate(nil) } }
            source.resume(); terminationSources.append(source)
        }
        controller.onChange = { [weak self] in
            guard let self else { return }
            updateStatus()
            if popover.isShown { quickControls.refresh() }
            if preferences?.window.isVisible == true { preferences?.refresh() }
        }
        controller.onResizeMode = { [weak self] active in self?.showResizeHint(active) }
        hotkeys.add(kVK_ANSI_R) { [weak self] in self?.controller.toggleResize() }
        hotkeys.add(kVK_ANSI_O) { [weak self] in self?.controller.rotateFocused() }
        hotkeys.add(kVK_ANSI_Y) { [weak self] in self?.controller.toggle() }
        hotkeys.add(kVK_ANSI_G) { [weak self] in self?.controller.floatFocused() }
        hotkeys.add(kVK_ANSI_T, shift: true) { [weak self] in self?.controller.toggleAll() }
        hotkeys.add(kVK_ANSI_T) { [weak self] in self?.controller.toggle() }
        hotkeys.add(kVK_ANSI_F) { [weak self] in self?.controller.floatFocused() }
        hotkeys.add(kVK_ANSI_M) { [weak self] in self?.controller.nextMonitor() }
        hotkeys.add(kVK_ANSI_Equal) { [weak self] in self?.controller.resize(0.05) }
        hotkeys.add(kVK_ANSI_Minus) { [weak self] in self?.controller.resize(-0.05) }
        for (key, x, y) in [(kVK_LeftArrow, -1.0, 0.0), (kVK_RightArrow, 1.0, 0.0), (kVK_UpArrow, 0.0, -1.0), (kVK_DownArrow, 0.0, 1.0)] {
            hotkeys.add(key) { [weak self] in self?.controller.neighbor(x, y) }
            hotkeys.add(key, command: true) { [weak self] in self?.controller.resizeDirection(x, y) }
            hotkeys.add(key, shift: true) { [weak self] in self?.controller.neighbor(x, y, swap: true) }
        }
        updateStatus()
        if CommandLine.arguments.contains("--show-settings") { showPreferences() }
        if CommandLine.arguments.contains("--show-controls") { DispatchQueue.main.async { self.togglePopover() } }
    }
    func updateStatus() {
        let active = controller.monitorTiling.active.count
        status.button?.title = controller.resizeMode ? " ↔" : active > 0 ? " \(active)/\(controller.screens.count)" : ""
        status.button?.toolTip = "CosmicTile · \(active) monitores com tiling · Control + Option + T alterna a tela focada"
    }
    func showPreferences() {
        if preferences == nil { preferences = Preferences(controller: controller) }
        preferences?.openQuickControls = { [weak self] in self?.togglePopover() }
        preferences?.show()
    }
    func showResizeHint(_ active: Bool) {
        resizeKeys.forEach { hotkeys.remove($0) }; resizeKeys.removeAll()
        if active {
            for (key, x, y) in [(kVK_LeftArrow, -1.0, 0.0), (kVK_RightArrow, 1.0, 0.0), (kVK_UpArrow, 0.0, -1.0), (kVK_DownArrow, 0.0, 1.0)] {
                if let id = hotkeys.add(key, modifiers: 0, action: { [weak self] in self?.controller.resizeDirection(x, y) }) { resizeKeys.append(id) }
            }
            for key in [kVK_Escape, kVK_Return] {
                if let id = hotkeys.add(key, modifiers: 0, action: { [weak self] in self?.controller.toggleResize() }) { resizeKeys.append(id) }
            }
        }
        resizeHint?.orderOut(nil)
        updateStatus()
        guard active else { return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 94), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96)
        panel.hasShadow = true; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let text = NSTextField(wrappingLabelWithString: "REDIMENSIONAR\n← reduzir largura   → aumentar largura\n↑ reduzir altura   ↓ aumentar altura   ·   Esc ou ⌃⌥R para sair")
        text.alignment = .center; text.font = .systemFont(ofSize: 14, weight: .medium)
        text.frame = NSRect(x: 16, y: 12, width: 468, height: 70)
        panel.contentView?.addSubview(text)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame { panel.setFrameOrigin(NSPoint(x: frame.midX - 250, y: frame.minY + 28)) }
        panel.orderFrontRegardless(); resizeHint = panel
    }
    @objc func togglePopover() {
        if popover.isShown { popover.performClose(nil); return }
        commandTarget = Accessibility.focused()
        controller.commandWindow = commandTarget
        quickControls.refresh()
        guard let button = status.button else { return }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        popoverKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let dismissed = MainActor.assumeIsolated {
                if event.keyCode == 53, self?.popover.isShown == true { self?.popover.performClose(nil); return true }
                return false
            }
            return dismissed ? nil : event
        }
    }
    func popoverDidClose(_ notification: Notification) {
        if let monitor = popoverKeyMonitor { NSEvent.removeMonitor(monitor) }
        popoverKeyMonitor = nil; commandTarget = nil; controller.commandWindow = nil
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPreferences(); return true }
    func applicationWillTerminate(_ notification: Notification) { controller.stop() }
}
if CommandLine.arguments.contains("--diagnose") {
    print("CosmicTile: accessibility=\(AXIsProcessTrusted()), monitors=\(NSScreen.screens.count)")
    exit(0)
}
if CommandLine.arguments.contains("--verify-brand") {
    guard Bundle.main.url(forResource: "CosmicTile", withExtension: "icns") != nil,
          Bundle.main.url(forResource: "AppIcon", withExtension: "png") != nil,
          let appIcon = BrandAssets.image("AppIcon"), appIcon.isValid,
          let menuIcon = BrandAssets.statusImage(), menuIcon.isTemplate, menuIcon.isValid else {
        print("Missing or invalid packaged CosmicTile artwork"); exit(1)
    }
    print("Verified CosmicTile application icon, ICNS resource and menu-bar template"); exit(0)
}
if CommandLine.arguments.contains("--check-updates") {
    let currentIndex = CommandLine.arguments.firstIndex(of: "--current-version")
    let current = currentIndex.flatMap { CommandLine.arguments.indices.contains($0 + 1) ? CommandLine.arguments[$0 + 1] : nil } ?? Updater.currentVersion
    Task {
        do {
            let candidate = try await UpdateService().check(current: current)
            print(candidate.map { "Available: \($0.tag) · \($0.fileName) · SHA-256 \($0.sha256)" } ?? "No newer compatible release")
            exit(0)
        } catch { print("Update check failed: \(error.localizedDescription)"); exit(1) }
    }
    RunLoop.main.run()
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
