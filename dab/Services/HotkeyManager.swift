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

    func register(keyCode: UInt32, modifiers: UInt32) {
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
        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
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
