import Carbon

@MainActor final class Hotkeys {
    var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 0
    var handler: EventHandlerRef?
    var actions: [UInt32: () -> Void] = [:]
    var unavailable = 0
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            MainActor.assumeIsolated {
                Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue().actions[identifier.id]?()
            }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    @discardableResult func add(_ key: Int, shift: Bool = false, command: Bool = false, modifiers: UInt32? = nil, action: @escaping () -> Void) -> UInt32? {
        nextID += 1; let id = nextID; actions[id] = action
        var ref: EventHotKeyRef?
        let flags = modifiers ?? UInt32(controlKey | optionKey | (shift ? shiftKey : 0) | (command ? cmdKey : 0))
        if RegisterEventHotKey(UInt32(key), flags, EventHotKeyID(signature: 0x4354494C, id: id), GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
            refs[id] = ref; return id
        }
        unavailable += 1; actions.removeValue(forKey: id); return nil
    }
    func remove(_ id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        actions.removeValue(forKey: id)
    }
}
