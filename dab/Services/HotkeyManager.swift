import Carbon
import AppKit

final class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var callback: (() -> Void)?

    init() {}

    init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    /// Registers the global hotkey. Returns `true` on success. On failure
    /// (e.g. the combo is already claimed system-wide, or `modifiers == 0`
    /// yields `paramErr`) it rolls back any partial registration and returns
    /// `false` so callers can surface the problem instead of leaving the user
    /// with a silently dead hotkey.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        unregister()

        let hotkeyID = EventHotKeyID(signature: OSType(0x5058_4C52), // "PXLR"
                                      id: 1)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        // Install handler
        let handlerCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.callback?()
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handlerCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        guard installStatus == noErr else {
            unregister()
            return false
        }

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        guard registerStatus == noErr else {
            // Roll back the installed handler so we don't leave a partial
            // registration behind.
            unregister()
            return false
        }

        return true
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}
