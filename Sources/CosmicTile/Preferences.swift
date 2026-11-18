import AppKit
import TileCore

@MainActor final class Preferences: NSObject {
    let controller: Controller
    private(set) var window: NSWindow!
    var openQuickControls: (() -> Void)?
    private let body = NSStackView()
    private var tabs: NSSegmentedControl!
    init(controller: Controller) {
        self.controller = controller
        super.init()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 840), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "CosmicTile · Ajustes"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(srgbRed: 0.075, green: 0.085, blue: 0.11, alpha: 1)
        window.contentView = PreferencesBackground()
        let root = NSStackView(); root.orientation = .vertical; root.alignment = .leading; root.spacing = 18
        root.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!
        content.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28), root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28), root.topAnchor.constraint(equalTo: content.topAnchor, constant: 24)])
        let brand = label("▦   COSMICTILE", size: 13, weight: .bold, color: .systemCyan)
        let brandRow = NSStackView(); brandRow.orientation = .horizontal
        brandRow.addArrangedSubview(brand)
        let space = NSView(); space.setContentHuggingPriority(.defaultLow, for: .horizontal); brandRow.addArrangedSubview(space)
        let quick = ActionButton("Controles rápidos ▾") { [weak self] in self?.openQuickControls?() }; quick.bezelStyle = .rounded
        brandRow.addArrangedSubview(quick); root.addArrangedSubview(brandRow)
        brandRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        root.addArrangedSubview(label("Cada tela, seu ritmo.", size: 30, weight: .bold))
        root.addArrangedSubview(label("Tiling independente por monitor. Foco sempre à vista.", size: 14, color: .secondaryLabelColor))
        tabs = NSSegmentedControl(labels: ["Monitores e destaque", "Atalhos de teclado"], trackingMode: .selectOne, target: self, action: #selector(tabChanged))
        tabs.selectedSegment = 0; root.addArrangedSubview(tabs)
        body.orientation = .vertical; body.alignment = .leading; body.spacing = 14
        root.addArrangedSubview(body)
        body.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let footer = NSStackView(); footer.orientation = .horizontal; footer.spacing = 12
        footer.addArrangedSubview(label("v0.3.0 · Swift + AppKit · Inspirado no COSMIC", size: 11, color: .secondaryLabelColor))
        let github = ActionButton("GitHub ↗") { NSWorkspace.shared.open(URL(string: "https://github.com/hckmseduardo/MacCosmicTile")!) }
        github.bezelStyle = .inline; footer.addArrangedSubview(github)
        root.addArrangedSubview(footer)
        refresh()
    }
    func show() { refresh(); window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate() }
    @objc private func tabChanged() { refresh() }
    func refresh() {
        for child in body.arrangedSubviews { body.removeArrangedSubview(child); child.removeFromSuperview() }
        if tabs.selectedSegment == 1 { buildShortcuts(); return }
        let preview = LayoutPreview()
        preview.accent = controller.focusIndicator.accent.color
        preview.showHint = controller.focusIndicator.enabled
        preview.hintThickness = controller.focusIndicator.thickness
        body.addArrangedSubview(preview)
        preview.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 180).isActive = true
        var monitorRows: [NSView] = []
        for (key, _) in controller.screens {
            let active = controller.monitorTiling.isEnabled(key)
            let row = NSStackView(); row.orientation = .horizontal; row.spacing = 12
            row.addArrangedSubview(label(controller.screenNames[key] ?? key, size: 13, weight: .medium))
            let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal); row.addArrangedSubview(spacer)
            let toggle = ActionButton(active ? "Ativado" : "Desativado") { [weak self] in self?.controller.toggle(monitor: key) }
            toggle.setButtonType(.switch); toggle.state = active ? .on : .off
            row.addArrangedSubview(toggle); monitorRows.append(row)
        }
        let all = ActionButton(controller.monitorTiling.active.count == controller.screens.count ? "Desativar todos e restaurar" : "Ativar todos os monitores") { [weak self] in self?.controller.toggleAll() }
        all.bezelStyle = .rounded; monitorRows.append(all)
        addCard("MONITORES", subtitle: "Control + Option + T alterna apenas a tela da janela focada.", contents: monitorRows)
        let enabledHint = ActionButton("Destacar janela ativa") { [weak self] in
            guard let self else { return }; controller.focusIndicator.enabled.toggle(); controller.refreshFocusHint(); refresh()
        }
        enabledHint.setButtonType(.switch); enabledHint.state = controller.focusIndicator.enabled ? .on : .off
        let colors = NSStackView(); colors.orientation = .horizontal; colors.spacing = 8
        colors.addArrangedSubview(label("Cor", size: 12, color: .secondaryLabelColor))
        for accent in FocusIndicator.Accent.allCases {
            let button = ActionButton("\(controller.focusIndicator.accent == accent ? "● " : "○ ")\(accent.name)") { [weak self] in
                self?.controller.focusIndicator.accent = accent; self?.controller.refreshFocusHint(); self?.refresh()
            }
            button.bezelStyle = .rounded; button.contentTintColor = accent.color; colors.addArrangedSubview(button)
        }
        let widths = NSStackView(); widths.orientation = .horizontal; widths.spacing = 8
        widths.addArrangedSubview(label("Espessura", size: 12, color: .secondaryLabelColor))
        for width in [2, 3, 5] {
            let button = ActionButton("\(Int(controller.focusIndicator.thickness) == width ? "✓ " : "")\(width) pt") { [weak self] in
                self?.controller.focusIndicator.thickness = CGFloat(width); self?.controller.refreshFocusHint(); self?.refresh()
            }
            button.bezelStyle = .rounded; widths.addArrangedSubview(button)
        }
        addCard("DESTAQUE DA JANELA", subtitle: "Uma borda acompanha o foco nas telas com tiling ativo.", contents: [enabledHint, colors, widths])
        let trusted = AXIsProcessTrusted()
        let permission = ActionButton(trusted ? "Acessibilidade autorizada ✓" : "Abrir ajustes de Acessibilidade…") {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        permission.bezelStyle = .rounded
        body.addArrangedSubview(permission)
    }
    private func buildShortcuts() {
        let shortcuts = [
            ("⌃⌥ T / Y", "Ativar ou desativar o monitor da janela focada"),
            ("⌃⌥⇧ T", "Ativar ou desativar todos os monitores"),
            ("⌃⌥ F / G", "Alternar janela entre tiling e flutuante"),
            ("⌃⌥ ← ↑ ↓ →", "Focar a janela nessa direção"),
            ("⌃⌥⇧ ← ↑ ↓ →", "Trocar a posição de duas janelas"),
            ("⌃⌥ R", "Entrar ou sair do modo de redimensionamento"),
            ("← / → no modo R", "Reduzir / aumentar a largura"),
            ("↑ / ↓ no modo R", "Reduzir / aumentar a altura"),
            ("⌃⌥⌘ ← ↑ ↓ →", "Redimensionar diretamente, sem modo R"),
            ("⌃⌥ O", "Alternar a orientação da divisão"),
            ("⌃⌥ M", "Enviar a janela ao próximo monitor"),
            ("⌃⌥ = / −", "Ajustar a proporção da divisão imediata")
        ]
        var rows: [NSView] = []
        for (keys, description) in shortcuts {
            let row = NSStackView(); row.orientation = .horizontal; row.spacing = 18
            let keyLabel = label(keys, size: 13, weight: .semibold, color: .systemCyan)
            keyLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
            keyLabel.widthAnchor.constraint(equalToConstant: 160).isActive = true
            row.addArrangedSubview(keyLabel); row.addArrangedSubview(label(description, size: 13)); rows.append(row)
        }
        addCard("SEU FLUXO, PELO TECLADO", subtitle: "Os atalhos de layout atuam nos monitores com tiling ativado.", contents: rows)
        addCard("COMO LER OS SÍMBOLOS", subtitle: "⌃ Control     ⌥ Option (Alt)     ⌘ Command     ⇧ Shift", contents: [label("Para redimensionar: Control + Option + R, use as setas,\ndepois pressione Esc ou repita o atalho para sair.", size: 14)])
    }
    private func addCard(_ title: String, subtitle: String, contents: [NSView]) {
        let card = NSView(); card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(srgbRed: 0.12, green: 0.135, blue: 0.17, alpha: 1).cgColor
        card.layer?.cornerRadius = 14
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false; card.addSubview(stack)
        stack.addArrangedSubview(label(title, size: 11, weight: .bold, color: .secondaryLabelColor))
        stack.addArrangedSubview(label(subtitle, size: 12, color: .secondaryLabelColor))
        for content in contents { stack.addArrangedSubview(content); content.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18), stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18), stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16), stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)])
        body.addArrangedSubview(card); card.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
    }
    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text); field.font = .systemFont(ofSize: size, weight: weight); field.textColor = color
        return field
    }

}

@MainActor final class ActionButton: NSButton {
    private let operation: () -> Void
    init(_ title: String, operation: @escaping () -> Void) {
        self.operation = operation
        super.init(frame: .zero); self.title = title; self.target = self; self.action = #selector(run)
    }
    required init?(coder: NSCoder) { nil }
    @objc private func run() { operation() }
}

@MainActor final class LayoutPreview: NSView {
    var accent = NSColor.systemCyan
    var showHint = true
    var hintThickness: CGFloat = 3
    override func draw(_ dirtyRect: NSRect) {
        let background = NSColor(srgbRed: 0.055, green: 0.065, blue: 0.09, alpha: 1)
        background.setFill(); NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14).fill()
        let left = CGRect(x: 22, y: 36, width: bounds.width * 0.57, height: 119)
        let right = CGRect(x: left.maxX + 18, y: 36, width: bounds.width - left.maxX - 40, height: 119)
        NSColor(srgbRed: 0.15, green: 0.17, blue: 0.21, alpha: 1).setFill()
        NSBezierPath(roundedRect: left, xRadius: 8, yRadius: 8).fill()
        NSBezierPath(roundedRect: right, xRadius: 8, yRadius: 8).fill()
        let tree = Layout.split(.horizontal, 0.58, .leaf(1), .split(.vertical, 0.5, .leaf(2), .leaf(3)))
        let frames = tree.frames(in: left.insetBy(dx: 7, dy: 7), gap: 6)
        for id in [1, 2, 3] {
            if let frame = frames[id] { tile(frame, title: [1: "Editor", 2: "Terminal", 3: "Browser"][id]!, focused: id == 1) }
        }
        tile(CGRect(x: right.minX + 12, y: right.minY + 16, width: right.width - 40, height: 76), title: "Notas", focused: false)
        tile(CGRect(x: right.minX + 28, y: right.minY + 7, width: right.width - 40, height: 64), title: "Arquivos", focused: false)
        drawText("TILING ATIVO", at: CGPoint(x: left.minX, y: 16), color: accent, size: 10)
        drawText("MODO LIVRE", at: CGPoint(x: right.minX, y: 16), color: .secondaryLabelColor, size: 10)
        drawText("Prévia ilustrativa", at: CGPoint(x: bounds.width - 130, y: 161), color: .secondaryLabelColor, size: 9)
    }
    private func tile(_ frame: CGRect, title: String, focused: Bool) {
        NSColor(srgbRed: 0.22, green: 0.24, blue: 0.29, alpha: 1).setFill()
        NSBezierPath(roundedRect: frame, xRadius: 7, yRadius: 7).fill()
        drawText(title, at: CGPoint(x: frame.minX + 10, y: frame.maxY - 23), color: .white, size: 11)
        if focused && showHint { OutlineView.drawOutline(in: frame, color: accent, thickness: hintThickness) }
    }
    private func drawText(_ text: String, at point: CGPoint, color: NSColor, size: CGFloat) {
        (text as NSString).draw(at: point, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color])
    }
}

@MainActor final class PreferencesBackground: NSView {
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed: 0.075, green: 0.085, blue: 0.11, alpha: 1).setFill()
        dirtyRect.fill()
    }
}
