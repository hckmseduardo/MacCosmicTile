import AppKit

/// A transient popover avoids entering NSMenu's blocking tracking loop.
@MainActor final class QuickControls: NSViewController {
    let controller: Controller
    var dismiss: (() -> Void)?
    var settings: (() -> Void)?
    var executeWindowCommand: ((() -> Void) -> Void)?
    private let stack = NSStackView()
    init(controller: Controller) { self.controller = controller; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { nil }
    override func loadView() {
        view = PreferencesBackground(frame: NSRect(x: 0, y: 0, width: 430, height: 680))
        view.appearance = NSAppearance(named: .darkAqua)
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20), stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18)])
        refresh()
    }
    func refresh() {
        guard isViewLoaded else { return }
        for child in stack.arrangedSubviews { stack.removeArrangedSubview(child); child.removeFromSuperview() }
        let header = NSStackView(); header.orientation = .horizontal; header.spacing = 12
        let icon = NSImageView(image: BrandAssets.image("AppIcon") ?? NSImage())
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        header.addArrangedSubview(icon)
        let title = label("CosmicTile  ·  \(controller.monitorTiling.active.count)/\(controller.screens.count) telas", size: 15, bold: true)
        header.addArrangedSubview(title)
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal); header.addArrangedSubview(spacer)
        let close = ActionButton("Fechar ×") { [weak self] in self?.dismiss?() }; close.bezelStyle = .inline
        header.addArrangedSubview(close); add(header)
        add(label("TILING POR MONITOR", size: 10, bold: true))
        for (key, _) in controller.screens {
            let active = controller.monitorTiling.isEnabled(key)
            let toggle = ActionButton(controller.screenNames[key] ?? key) { [weak self] in self?.controller.toggle(monitor: key); self?.refresh() }
            toggle.setButtonType(.switch); toggle.state = active ? .on : .off; add(toggle)
        }
        button("Alternar monitor focado                 ⌃⌥T", windowCommand: true) { [weak self] in self?.controller.toggle() }
        button("Alternar todos os monitores         ⌃⌥⇧T") { [weak self] in self?.controller.toggleAll(); self?.refresh() }
        separator()
        let hint = ActionButton("Destacar janela ativa") { [weak self] in
            guard let self else { return }; controller.focusIndicator.enabled.toggle(); controller.refreshFocusHint(); refresh()
        }
        hint.setButtonType(.switch); hint.state = controller.focusIndicator.enabled ? .on : .off; add(hint)
        button("Ajustes, cores e guia de atalhos…") { [weak self] in self?.dismiss?(); self?.settings?() }
        separator()
        button("Redimensionar com setas                 ⌃⌥R", windowCommand: true) { [weak self] in self?.controller.toggleResize() }
        button("Alternar janela flutuante                    ⌃⌥F", windowCommand: true) { [weak self] in self?.controller.floatFocused() }
        button("Mover ao próximo monitor               ⌃⌥M", windowCommand: true) { [weak self] in self?.controller.nextMonitor() }
        button("Alternar orientação da divisão           ⌃⌥O", windowCommand: true) { [weak self] in self?.controller.rotateFocused() }
        separator()
        let gaps = NSStackView(); gaps.orientation = .horizontal; gaps.spacing = 6
        gaps.addArrangedSubview(label("Espaço", size: 12))
        for value in [0, 6, 10, 16, 24] {
            let b = ActionButton("\(Int(controller.gap) == value ? "✓" : "")\(value)") { [weak self] in
                self?.controller.gap = Double(value); UserDefaults.standard.set(Double(value), forKey: "gap"); self?.controller.apply(); self?.refresh()
            }
            b.bezelStyle = .rounded; gaps.addArrangedSubview(b)
        }
        add(gaps)
        let automatic = ActionButton("Orientação automática das novas divisões") { [weak self] in self?.controller.automaticOrientation.toggle(); self?.refresh() }
        automatic.setButtonType(.switch); automatic.state = controller.automaticOrientation ? .on : .off; add(automatic)
        button("Nova divisão manual: \(controller.axis == .horizontal ? "horizontal" : "vertical")") { [weak self] in
            guard let self else { return }; controller.automaticOrientation = false; controller.axis = controller.axis == .horizontal ? .vertical : .horizontal; refresh()
        }
        if !AXIsProcessTrusted() {
            button("Permitir Acessibilidade…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
        if controller.failures > 0 { add(label("\(controller.failures) janelas recusaram ajuste", size: 11)) }
        add(label("Esc ou clique fora para fechar.\n⌃ Control  ·  ⌥ Option  ·  ⇧ Shift", size: 11))
        button("Sair e restaurar posições") { NSApp.terminate(nil) }
        view.layoutSubtreeIfNeeded()
        preferredContentSize = NSSize(width: 430, height: stack.fittingSize.height + 36)
    }
    private func add(_ child: NSView) {
        stack.addArrangedSubview(child); child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    private func label(_ text: String, size: CGFloat, bold: Bool = false) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        field.textColor = bold ? .labelColor : .secondaryLabelColor; return field
    }
    private func button(_ title: String, windowCommand: Bool = false, operation: @escaping () -> Void) {
        let button = ActionButton(title) { [weak self] in
            if windowCommand { self?.executeWindowCommand?(operation) }
            else { operation() }
        }
        button.bezelStyle = .rounded; add(button)
    }
    private func separator() {
        let line = NSBox(); line.boxType = .separator; add(line)
    }
}
