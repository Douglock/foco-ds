import Foundation
import AppKit
import Carbon

final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    var onHotKeyTriggered: (() -> Void)?

    private init() {}

    func registerDefaultHotKey() {
        unregisterHotKey()

        let hotKeyID = EventHotKeyID(signature: OSType(0x464F434F), id: 1) // 'FOCO', 1

        // Modifiers: optionKey (⌥)
        let modifiers = UInt32(optionKey)
        // Key code: kVK_ANSI_F (3)
        let keyCode = UInt32(kVK_ANSI_F)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            guard let event = event else { return noErr }
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &id
            )
            if status == noErr && id.id == 1 {
                DispatchQueue.main.async {
                    GlobalHotkeyManager.shared.onHotKeyTriggered?()
                }
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &eventHandler)

        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr {
            print("[GlobalHotkeyManager] Hotkey ⌥ + F registered successfully.")
        } else {
            print("[GlobalHotkeyManager] Failed to register hotkey: \(status)")
        }
    }

    func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregisterHotKey()
    }
}
