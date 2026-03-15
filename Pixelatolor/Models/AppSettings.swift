import SwiftUI
import Carbon

final class AppSettings {
    static let shared = AppSettings()

    var gridSize: Int {
        get { UserDefaults.standard.object(forKey: "gridSize") as? Int ?? 16 }
        set { UserDefaults.standard.set(newValue, forKey: "gridSize") }
    }

    var viewportSize: CGFloat {
        get { CGFloat(UserDefaults.standard.object(forKey: "viewportSize") as? Double ?? 200.0) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "viewportSize") }
    }

    var resizeStep: CGFloat {
        get { CGFloat(UserDefaults.standard.object(forKey: "resizeStep") as? Double ?? 10.0) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "resizeStep") }
    }

    var brightnessThreshold: Float {
        get { UserDefaults.standard.object(forKey: "brightnessThreshold") as? Float ?? 0.5 }
        set { UserDefaults.standard.set(newValue, forKey: "brightnessThreshold") }
    }

    var filterMode: FilterMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: "filterMode"),
               let mode = FilterMode(rawValue: raw) {
                return mode
            }
            return .threshold
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "filterMode") }
    }

    var mirrorHorizontal: Bool {
        get { UserDefaults.standard.bool(forKey: "mirrorHorizontal") }
        set { UserDefaults.standard.set(newValue, forKey: "mirrorHorizontal") }
    }

    var mirrorVertical: Bool {
        get { UserDefaults.standard.bool(forKey: "mirrorVertical") }
        set { UserDefaults.standard.set(newValue, forKey: "mirrorVertical") }
    }

    var filenameFormat: String {
        get { UserDefaults.standard.string(forKey: "filenameFormat") ?? "pixelatolor_{date}_{time}" }
        set { UserDefaults.standard.set(newValue, forKey: "filenameFormat") }
    }

    var saveDirectory: URL {
        get {
            if let bookmark = UserDefaults.standard.data(forKey: "saveDirectoryBookmark") {
                var isStale = false
                if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    if !isStale {
                        return url
                    }
                }
            }
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        }
        set {
            if let bookmark = try? newValue.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(bookmark, forKey: "saveDirectoryBookmark")
            }
        }
    }

    var hotkeyKeyCode: UInt32 {
        get { UInt32(UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? Int ?? 35) } // 35 = 'P'
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyKeyCode") }
    }

    var hotkeyModifiers: UInt32 {
        get { UInt32(UserDefaults.standard.object(forKey: "hotkeyModifiers") as? Int ?? 0x0108) } // Cmd+Shift
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyModifiers") }
    }

    /// Formats the current hotkey as a human-readable string
    var hotkeyDisplayString: String {
        let mods = hotkeyModifiers
        var parts: [String] = []
        // Carbon modifier constants from Events.h
        if mods & 0x0100 != 0 { parts.append("Cmd") }     // cmdKey
        if mods & 0x0200 != 0 { parts.append("Shift") }   // shiftKey
        if mods & 0x0800 != 0 { parts.append("Option") }  // optionKey
        if mods & 0x1000 != 0 { parts.append("Control") } // controlKey

        let keyName = Self.keyCodeToString(hotkeyKeyCode)
        parts.append(keyName)
        return parts.joined(separator: "+")
    }

    static func keyCodeToString(_ keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".",
            49: "Space", 50: "`", 51: "Delete", 53: "Escape",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 109: "F10",
            111: "F12", 118: "F4", 120: "F2", 122: "F1",
            123: "Left", 124: "Right", 125: "Down", 126: "Up",
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }

    /// Converts NSEvent modifier flags to Carbon modifier mask for RegisterEventHotKey
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonMods: UInt32 = 0
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        return carbonMods
    }

    private init() {}
}
