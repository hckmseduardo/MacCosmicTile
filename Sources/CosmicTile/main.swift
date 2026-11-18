import AppKit
import Carbon

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let controller = Controller()
    let hotkeys = Hotkeys()
    var status: NSStatusItem!
    var resizeHint: NSPanel?
    var operations: [String: () -> Void] = [:]
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "▦"
        status.button?.toolTip = "CosmicTile · Control + Option + T para ativar"
        let menu = NSMenu(); menu.delegate = self; status.menu = menu
        controller.onChange = { [weak self] in self?.status.button?.title = self?.controller.enabled == true ? "▦ ON" : "▦" }
        controller.onResizeMode = { [weak self] active in self?.showResizeHint(active) }
        hotkeys.add(kVK_ANSI_R) { [weak self] in self?.controller.toggleResize() }
        hotkeys.add(kVK_ANSI_O) { [weak self] in self?.controller.rotateFocused() }
        hotkeys.add(kVK_ANSI_Y) { [weak self] in self?.controller.toggle() }
        hotkeys.add(kVK_ANSI_G) { [weak self] in self?.controller.floatFocused() }
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
    }
    func showResizeHint(_ active: Bool) {
        resizeHint?.orderOut(nil)
        status.button?.title = active ? "▦ ↔" : controller.enabled ? "▦ ON" : "▦"
        guard active else { return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 94), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96)
        panel.hasShadow = true; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let text = NSTextField(wrappingLabelWithString: "REDIMENSIONAR\n← reduzir largura   → aumentar largura\n↑ reduzir altura   ↓ aumentar altura   ·   ⌃⌥R para sair")
        text.alignment = .center; text.font = .systemFont(ofSize: 14, weight: .medium)
        text.frame = NSRect(x: 16, y: 12, width: 468, height: 70)
        panel.contentView?.addSubview(text)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame { panel.setFrameOrigin(NSPoint(x: frame.midX - 250, y: frame.minY + 28)) }
        panel.orderFrontRegardless(); resizeHint = panel
    }
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems(); operations.removeAll()
        func item(_ title: String, _ operation: (() -> Void)? = nil) {
            let entry = NSMenuItem(title: title, action: operation == nil ? nil : #selector(performMenu(_:)), keyEquivalent: "")
            entry.target = self; menu.addItem(entry); operations[title] = operation
        }
        item("CosmicTile · \(controller.screens.count) monitores")
        item(controller.enabled ? "Desativar e restaurar · ⌃⌥T" : "Ativar tiling · ⌃⌥T") { [weak self] in self?.controller.toggle() }
        if !AXIsProcessTrusted() {
            item("Permitir Acessibilidade…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
        menu.addItem(.separator())
        item("Alternar janela flutuante · ⌃⌥F") { [weak self] in self?.controller.floatFocused() }
        item("Mover ao próximo monitor · ⌃⌥M") { [weak self] in self?.controller.nextMonitor() }
        item(controller.resizeMode ? "Sair do modo redimensionar · ⌃⌥R" : "Redimensionar com setas · ⌃⌥R") { [weak self] in self?.controller.toggleResize() }
        item("Alternar orientação da janela · ⌃⌥O") { [weak self] in self?.controller.rotateFocused() }
        item("\(controller.automaticOrientation ? "✓ " : "")Orientação automática") { [weak self] in self?.controller.automaticOrientation.toggle() }
        item("Nova divisão: \(controller.axis == .horizontal ? "horizontal" : "vertical")") { [weak self] in
            guard let self else { return }; controller.automaticOrientation = false; controller.axis = controller.axis == .horizontal ? .vertical : .horizontal
        }
        for gap in [0, 6, 10, 16, 24] {
            item("\(Int(controller.gap) == gap ? "✓ " : "")Espaçamento: \(gap) px") { [weak self] in
                self?.controller.gap = Double(gap); UserDefaults.standard.set(Double(gap), forKey: "gap"); self?.controller.apply()
            }
        }
        menu.addItem(.separator())
        item("Focar: ⌃⌥ setas · Trocar: ⌃⌥⇧ setas")
        item("Redimensionar direto: ⌃⌥⌘ setas")
        item("Proporção da divisão: ⌃⌥ + / −")
        if hotkeys.unavailable > 0 { item("\(hotkeys.unavailable) atalhos indisponíveis por conflito") }
        if controller.failures > 0 { item("\(controller.failures) janelas recusaram ajuste") }
        item("Sair e restaurar") { NSApp.terminate(nil) }
    }
    @objc func performMenu(_ sender: NSMenuItem) { operations[sender.title]?() }
    func applicationWillTerminate(_ notification: Notification) { controller.stop() }
}
if CommandLine.arguments.contains("--diagnose") {
    print("CosmicTile: accessibility=\(AXIsProcessTrusted()), monitors=\(NSScreen.screens.count)")
    exit(0)
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
