import Foundation
import CoreGraphics

/// Session state: newly attached screens never start moving windows unexpectedly.
public struct MonitorTiling: Sendable {
    public private(set) var active: Set<String> = []
    public init() {}
    public func isEnabled(_ id: String) -> Bool { active.contains(id) }
    public mutating func toggle(_ id: String) {
        if !active.insert(id).inserted { active.remove(id) }
    }
    public mutating func toggleAll(connected: Set<String>) {
        if connected.isSubset(of: active) { active.removeAll() }
        else { active = connected }
    }
    public mutating func reconcile(connected: Set<String>) { active.formIntersection(connected) }
    public mutating func disableAll() { active.removeAll() }
}

public enum ScreenGeometry {
    public static func usableFrame(screen: CGRect, visible: CGRect, desktopTop: CGFloat, menuBarHeight: CGFloat) -> CGRect {
        // Secondary visibleFrame can include the menu bar although AX clamps windows below it.
        let top = min(visible.maxY, screen.maxY - max(0, menuBarHeight))
        return CGRect(x: visible.minX, y: desktopTop - top, width: visible.width, height: max(0, top - visible.minY))
    }
    public static func appKitFrame(_ quartz: CGRect, desktopTop: CGFloat) -> CGRect {
        CGRect(x: quartz.minX, y: desktopTop - quartz.maxY, width: quartz.width, height: quartz.height)
    }
    public static func clamped(_ frame: CGRect, to bounds: CGRect) -> CGRect {
        let width = min(frame.width, bounds.width)
        let height = min(frame.height, bounds.height)
        return CGRect(x: min(max(frame.minX, bounds.minX), bounds.maxX - width),
                      y: min(max(frame.minY, bounds.minY), bounds.maxY - height), width: width, height: height)
    }
}
