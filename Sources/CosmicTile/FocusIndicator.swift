import AppKit
import TileCore

@MainActor final class FocusIndicator {
    enum Accent: String, CaseIterable {
        case cyan, violet, orange
        var name: String { switch self { case .cyan: "Ciano"; case .violet: "Violeta"; case .orange: "Laranja" } }
        var color: NSColor {
            switch self {
            case .cyan: NSColor(srgbRed: 0.24, green: 0.86, blue: 0.92, alpha: 1)
            case .violet: NSColor(srgbRed: 0.70, green: 0.56, blue: 1, alpha: 1)
            case .orange: NSColor(srgbRed: 1, green: 0.65, blue: 0.32, alpha: 1)
            }
        }
    }
    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "activeHintEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "activeHintEnabled"); if !newValue { hide() } }
    }
    var accent: Accent {
        get { Accent(rawValue: UserDefaults.standard.string(forKey: "activeHintAccent") ?? "cyan") ?? .cyan }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "activeHintAccent"); outline.color = newValue.color; outline.needsDisplay = true }
    }
    var thickness: CGFloat {
        get { CGFloat(UserDefaults.standard.object(forKey: "activeHintThickness") as? Double ?? 3) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "activeHintThickness"); outline.thickness = newValue; outline.needsDisplay = true }
    }
    private let panel: NSPanel
    private let outline: OutlineView
    init() {
        outline = OutlineView()
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
        panel.level = .floating; panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false; panel.contentView = outline
        outline.color = accent.color; outline.thickness = thickness
    }
    func show(around quartzFrame: CGRect) {
        guard enabled, !quartzFrame.isEmpty, quartzFrame.isFinite else { hide(); return }
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let frame = ScreenGeometry.appKitFrame(quartzFrame, desktopTop: top)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
    func hide() { panel.orderOut(nil) }
}

@MainActor final class OutlineView: NSView {
    var color = NSColor.systemCyan
    var thickness: CGFloat = 3
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Self.drawOutline(in: bounds, color: color, thickness: thickness)
    }
    static func drawOutline(in rect: CGRect, color: NSColor, thickness: CGFloat) {
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: thickness / 2, dy: thickness / 2), xRadius: 10, yRadius: 10)
        path.lineWidth = thickness; color.setStroke(); path.stroke()
    }
}

private extension CGRect {
    var isFinite: Bool { origin.x.isFinite && origin.y.isFinite && size.width.isFinite && size.height.isFinite }
}
