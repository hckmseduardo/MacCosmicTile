import AppKit
import TileCore

@MainActor final class Controller {
    var monitorTiling = MonitorTiling()
    var enabled: Bool { !monitorTiling.active.isEmpty }
    var originalMonitors: [Int: String] = [:]
    let focusIndicator = FocusIndicator()
    var lastReconciliation = Date.distantPast
    var gap: Double = UserDefaults.standard.object(forKey: "gap") as? Double ?? 10
    var axis: Axis = .horizontal
    var automaticOrientation = true
    var previousFocus: Int?
    var commandWindow: AXUIElement?
    var lastScreens: [String: CGRect] = [:]
    var resizeMode = false
    var onResizeMode: ((Bool) -> Void)?
    var layouts: [String: Layout] = [:]
    var windows: [Int: ManagedWindow] = [:]
    var originals: [Int: CGRect] = [:]
    var originalWindows: [Int: AXUIElement] = [:]
    var floating: Set<Int> = []
    var timer: Timer?
    var failures = 0
    var onChange: (() -> Void)?
    var screens: [(String, CGRect)] {
        let primary = NSScreen.screens.first
        let top = primary?.frame.maxY ?? 0
        let menuHeight = primary.map { max(0, $0.frame.maxY - $0.visibleFrame.maxY) } ?? 0
        return NSScreen.screens.map { screen in
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? screen.localizedName
            return (id, ScreenGeometry.usableFrame(screen: screen.frame, visible: screen.visibleFrame, desktopTop: top, menuBarHeight: menuHeight))
        }
    }
    func monitor(for rect: CGRect) -> String? {
        screens.max { a, b in
            let ar = a.1.intersection(rect); let br = b.1.intersection(rect)
            return (ar.isNull ? 0 : ar.width * ar.height) < (br.isNull ? 0 : br.width * br.height)
        }?.0
    }
    var screenNames: [String: String] {
        Dictionary(NSScreen.screens.enumerated().map { index, screen in
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? screen.localizedName
            return (id, "Monitor \(index + 1) · \(screen.localizedName)")
        }, uniquingKeysWith: { a, _ in a })
    }
    func focusedMonitor() -> String? {
        if let focused = commandWindow ?? Accessibility.focused(), let rect = Accessibility.frame(focused), let id = monitor(for: rect) { return id }
        let pointer = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) {
            return (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? screen.localizedName
        }
        return screens.first?.0
    }
    func ensurePermission() -> Bool {
        guard AXIsProcessTrusted() else {
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            return false
        }
        return true
    }
    func startTimerIfNeeded() {
        guard enabled, timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if Date().timeIntervalSince(self.lastReconciliation) >= 0.35 {
                    self.reconcile(); self.lastReconciliation = Date()
                }
                self.refreshFocusHint()
            }
        }
    }
    func toggle(monitor requested: String? = nil) {
        guard let key = requested ?? focusedMonitor(), screens.contains(where: { $0.0 == key }) else { return }
        let wasEnabled = monitorTiling.isEnabled(key)
        if !wasEnabled && !ensurePermission() { return }
        monitorTiling.toggle(key)
        if wasEnabled { releaseMonitor(key) }
        if enabled { startTimerIfNeeded(); reconcile() }
        else { timer?.invalidate(); timer = nil }
        resizeMode = false; onResizeMode?(false)
        refreshFocusHint(); onChange?()
    }
    func toggleAll() {
        let connected = Set(screens.map(\.0))
        if connected.isSubset(of: monitorTiling.active) { stop(); return }
        guard ensurePermission() else { return }
        monitorTiling.toggleAll(connected: connected)
        startTimerIfNeeded(); reconcile(); refreshFocusHint(); onChange?()
    }
    func releaseMonitor(_ key: String) {
        let owned = originalMonitors.filter { $0.value == key }.map(\.key)
        let bounds = screens.first(where: { $0.0 == key })?.1
        for id in owned {
            if let element = originalWindows[id], let frame = originals[id], let actual = Accessibility.frame(element), monitor(for: actual) == key {
                Accessibility.setFrame(bounds.map { ScreenGeometry.clamped(frame, to: $0) } ?? frame, of: element)
            }
            originals.removeValue(forKey: id); originalWindows.removeValue(forKey: id)
            originalMonitors.removeValue(forKey: id); floating.remove(id)
        }
        layouts.removeValue(forKey: key)
    }
    func stop() {
        timer?.invalidate(); timer = nil
        resizeMode = false; onResizeMode?(false); previousFocus = nil; lastScreens.removeAll()
        for key in Set(originalMonitors.values) { releaseMonitor(key) }
        monitorTiling.disableAll(); layouts.removeAll()
        originals.removeAll(); originalWindows.removeAll(); originalMonitors.removeAll(); floating.removeAll()
        focusIndicator.hide(); onChange?()
    }
    func refreshFocusHint() {
        guard enabled, AXIsProcessTrusted(), let element = Accessibility.focused(),
              let rect = Accessibility.frame(element), let key = monitor(for: rect), monitorTiling.isEnabled(key) else {
            focusIndicator.hide(); return
        }
        let id = Int(CFHash(element))
        guard layouts[key]?.ids.contains(id) == true || floating.contains(id) else { focusIndicator.hide(); return }
        focusIndicator.show(around: rect)
        if windows[id] != nil { previousFocus = id }
    }
    func reconcile() {
        guard enabled, AXIsProcessTrusted() else { if enabled { stop() }; return }
        // Never fight an in-progress mouse drag or resize.
        guard (NSEvent.pressedMouseButtons & 1) == 0 else { return }
        let before = layouts
        let screenSnapshot = Dictionary(screens, uniquingKeysWith: { a, _ in a })
        let focused = Accessibility.focused().map { Int(CFHash($0)) }
        let found = Accessibility.windows().sorted { a, b in
            if a.frame.minX != b.frame.minX { return a.frame.minX < b.frame.minX }
            if a.frame.minY != b.frame.minY { return a.frame.minY < b.frame.minY }
            return a.id < b.id
        }
        windows = Dictionary(found.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let available = Set(screens.map(\.0))
        let oldActive = monitorTiling.active
        monitorTiling.reconcile(connected: available)
        if oldActive != monitorTiling.active { onChange?() }
        if !enabled { timer?.invalidate(); timer = nil; focusIndicator.hide(); return }
        for key in Array(layouts.keys) {
            guard monitorTiling.isEnabled(key) else { layouts.removeValue(forKey: key); continue }
            for id in layouts[key]?.ids ?? [] {
                if windows[id] == nil || floating.contains(id) || windows[id].flatMap({ monitor(for: $0.frame) }) != key {
                    layouts[key] = layouts[key]?.removing(id)
                }
            }
        }
        for w in found where !floating.contains(w.id) {
            guard let key = monitor(for: w.frame), monitorTiling.isEnabled(key), !(layouts[key]?.ids.contains(w.id) ?? false) else { continue }
            if originalMonitors[w.id] != key { originals[w.id] = w.frame }
            originals[w.id] = originals[w.id] ?? w.frame
            originalWindows[w.id] = w.element; originalMonitors[w.id] = key
            let existing = layouts[key]?.ids ?? []
            let preferred = Placement.anchor(existing: existing, focused: focused, previous: previousFocus)
            let screen = screenSnapshot[key] ?? w.frame
            let tileFrames = layouts[key]?.frames(in: screen.insetBy(dx: gap, dy: gap), gap: gap) ?? [:]
            let anchor = automaticOrientation ? Placement.target(frames: tileFrames, preferred: preferred, gap: gap) : preferred
            let region = anchor.flatMap { tileFrames[$0] } ?? screen
            let direction = automaticOrientation ? Placement.axis(for: region) : axis
            layouts[key] = layouts[key]?.inserting(w.id, beside: anchor, axis: direction) ?? .leaf(w.id)
        }
        if before != layouts || lastScreens != screenSnapshot { apply() }
        lastScreens = screenSnapshot
        if let focused, windows[focused] != nil { previousFocus = focused }
    }
    func apply() {
        guard enabled else { return }
        failures = 0
        for (key, rect) in screens where monitorTiling.isEnabled(key) {
            for (id, frame) in layouts[key]?.frames(in: rect.insetBy(dx: gap, dy: gap), gap: gap) ?? [:] {
                if let w = windows[id] {
                    if !Accessibility.setFrame(frame, of: w.element) { failures += 1 }
                    if let actual = Accessibility.frame(w.element) { windows[id] = ManagedWindow(id: id, element: w.element, frame: actual) }
                }
            }
        }
    }
    func current() -> (Int, String)? {
        guard let element = commandWindow ?? Accessibility.focused() else { return nil }
        let id = Int(CFHash(element))
        guard let key = layouts.first(where: { $0.value.ids.contains(id) })?.key ?? windows[id].flatMap({ monitor(for: $0.frame) }) else { return nil }
        return (id, key)
    }
    func floatFocused() {
        guard enabled, let (id, key) = current(), monitorTiling.isEnabled(key) else { return }
        if floating.remove(id) == nil {
            floating.insert(id); layouts[key] = layouts[key]?.removing(id)
            if let frame = originals[id], let w = windows[id] { Accessibility.setFrame(frame, of: w.element) }
        }
        reconcile(); apply()
    }
    func neighbor(_ dx: Double, _ dy: Double, swap: Bool = false) {
        if resizeMode && !swap { resizeDirection(dx, dy); return }
        guard enabled, let (id, key) = current(), let origin = windows[id]?.frame else { return }
        var candidates: [ManagedWindow] = []
        for candidateID in layouts[key]?.ids ?? [] {
            guard candidateID != id, let w = windows[candidateID] else { continue }
            let distanceX = Double(w.frame.midX - origin.midX)
            let distanceY = Double(w.frame.midY - origin.midY)
            if distanceX * dx + distanceY * dy > 1 { candidates.append(w) }
        }
        let target = candidates.min { a, b in
            func score(_ r: CGRect) -> Double {
                let x = r.midX - origin.midX; let y = r.midY - origin.midY
                return abs(x * dx + y * dy) + 3 * abs(x * dy - y * dx)
            }
            return score(a.frame) < score(b.frame)
        }
        guard let target else { return }
        if swap { layouts[key] = layouts[key]?.swapping(id, target.id); apply() }
        else { Accessibility.focus(target.element) }
    }
    func resize(_ delta: Double) {
        guard enabled, let (id, key) = current(), monitorTiling.isEnabled(key) else { return }
        layouts[key] = layouts[key]?.resizing(id, delta: delta); apply()
    }
    func nextMonitor() {
        guard enabled, let (id, key) = current(), let w = windows[id], screens.count > 1, let index = screens.firstIndex(where: { $0.0 == key }) else { return }
        let destination = screens[(index + 1) % screens.count]
        layouts[key] = layouts[key]?.removing(id); floating.remove(id)
        let transferFrame = ScreenGeometry.clamped(w.frame, to: destination.1.insetBy(dx: gap, dy: gap))
        var placed = transferFrame
        placed.origin = CGPoint(x: destination.1.minX + gap, y: destination.1.minY + gap)
        Accessibility.setFrame(placed, of: w.element)
        originals.removeValue(forKey: id); originalWindows.removeValue(forKey: id); originalMonitors.removeValue(forKey: id)
        if monitorTiling.isEnabled(destination.0) {
            originals[id] = placed; originalWindows[id] = w.element; originalMonitors[id] = destination.0
            layouts[destination.0] = layouts[destination.0]?.inserting(id, beside: nil, axis: axis) ?? .leaf(id)
        }
        apply(); Accessibility.focus(w.element); refreshFocusHint()
    }
    func toggleResize() {
        guard enabled, let (_, key) = current(), monitorTiling.isEnabled(key) else { return }
        resizeMode.toggle(); onResizeMode?(resizeMode)
    }
    func resizeDirection(_ x: Double, _ y: Double) {
        guard enabled, let (id, key) = current(), monitorTiling.isEnabled(key) else { return }
        let direction: Axis = x == 0 ? .vertical : .horizontal
        let delta = (x == 0 ? y : x) * 0.04
        layouts[key] = layouts[key]?.resizing(id, axis: direction, delta: delta)
        apply()
    }
    func rotateFocused() {
        guard enabled, let (id, key) = current(), monitorTiling.isEnabled(key) else { return }
        layouts[key] = layouts[key]?.rotating(id); apply()
    }
}
