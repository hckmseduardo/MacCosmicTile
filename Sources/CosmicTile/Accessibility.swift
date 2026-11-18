import AppKit
import ApplicationServices
import TileCore

struct ManagedWindow {
    let id: Int
    let element: AXUIElement
    let frame: CGRect
}

@MainActor enum Accessibility {
    static func value(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else { return nil }
        return result
    }
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let p = value(element, kAXPositionAttribute), let s = value(element, kAXSizeAttribute), CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero; var size = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(p, to: AXValue.self), .cgPoint, &point), AXValueGetValue(unsafeDowncast(s, to: AXValue.self), .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }
    static func windows() -> [ManagedWindow] {
        let visible = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }.flatMap { app in
            let root = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(root, 0.15)
            guard let elements = value(root, kAXWindowsAttribute) as? [AXUIElement] else { return [ManagedWindow]() }
            return elements.compactMap { element in
                var resizable = DarwinBoolean(false)
                _ = AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &resizable)
                guard WindowPolicy.allows(role: value(element, kAXRoleAttribute) as? String ?? "",
                                          subrole: value(element, kAXSubroleAttribute) as? String ?? "",
                                          modal: value(element, kAXModalAttribute) as? Bool ?? false,
                                          resizable: resizable.boolValue),
                      value(element, kAXMinimizedAttribute) as? Bool != true,
                      value(element, "AXFullScreen") as? Bool != true,
                      let rect = frame(element),
                      visible.contains(where: { info in
                          guard info[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier,
                                info[kCGWindowLayer as String] as? Int == 0,
                                let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                                let visibleFrame = CGRect(dictionaryRepresentation: bounds) else { return false }
                          return abs(visibleFrame.minX - rect.minX) < 3 && abs(visibleFrame.minY - rect.minY) < 3 && abs(visibleFrame.width - rect.width) < 3 && abs(visibleFrame.height - rect.height) < 3
                      }) else { return nil }
                return ManagedWindow(id: Int(CFHash(element)), element: element, frame: rect)
            }
        }
    }
    @discardableResult static func setFrame(_ frame: CGRect, of element: AXUIElement) -> Bool {
        var p = frame.origin; var s = frame.size
        let position = AXValueCreate(.cgPoint, &p)!
        let size = AXValueCreate(.cgSize, &s)!
        let a = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, size)
        let b = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, position)
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, size)
        return a == .success && b == .success
    }
    static func focused() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return value(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute).map { unsafeDowncast($0, to: AXUIElement.self) }
    }
    static func focus(_ element: AXUIElement) {
        var pid: pid_t = 0; AXUIElementGetPid(element, &pid)
        NSRunningApplication(processIdentifier: pid)?.activate()
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }
}
