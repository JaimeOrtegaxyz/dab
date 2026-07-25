import SwiftUI
import Carbon

final class AppSettings {
    static let shared = AppSettings()

    var gridSize: Int {
        // Clamp on read: gridSize is used as a divisor in cell-size math across
        // several files, so a 0/negative stored value (corruption or external
        // tampering) would yield inf/NaN. Mirror the UI stepper's 4...64 range.
        get { min(64, max(4, UserDefaults.standard.object(forKey: "gridSize") as? Int ?? 16)) }
        set { UserDefaults.standard.set(newValue, forKey: "gridSize") }
    }

    var viewportSize: CGFloat {
        // Clamp on read to the UI's supported range so an out-of-range stored
        // value can't produce a degenerate/negative-size overlay window.
        get { CGFloat(min(600, max(60, UserDefaults.standard.object(forKey: "viewportSize") as? Double ?? 200.0))) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "viewportSize") }
    }

    var resizeStep: CGFloat {
        // Clamp on read to the UI stepper's 5...50 range. resizeStep is used as a
        // multiplier for viewport key adjustments, so a 0/negative stored value
        // (corruption or external tampering) would make the resize keys no-op or
        // run backwards.
        get { CGFloat(min(50, max(5, UserDefaults.standard.object(forKey: "resizeStep") as? Double ?? 10.0))) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "resizeStep") }
    }

    var brightnessThreshold: Float {
        // Clamp on read to the UI slider's 0...1 range so an out-of-range stored
        // value can't over-bias the threshold/halftone bands.
        get {
            if let number = UserDefaults.standard.object(forKey: "brightnessThreshold") as? NSNumber {
                return min(1, max(0, number.floatValue))
            }
            return 0.5
        }
        set { UserDefaults.standard.set(newValue, forKey: "brightnessThreshold") }
    }

    var filterMode: FilterMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: "filterMode"),
               let mode = FilterMode(rawValue: raw) {
                return mode
            }
            return .colorMatch
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "filterMode") }
    }

    /// The render mode the overlay starts in; the `r` key still cycles live
    /// from there. Falls back to `.squares` for missing/corrupt raw values.
    var defaultRenderMode: RenderMode {
        get {
            let raw = UserDefaults.standard.object(forKey: "defaultRenderMode") as? Int
                ?? RenderMode.squares.rawValue
            return RenderMode(rawValue: raw) ?? .squares
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "defaultRenderMode") }
    }

    /// The most-recent palette-randomizer seed. Persisted so re-entering the
    /// randomizer in a future session resumes on the variation the user was
    /// last looking at (whether they exited or accepted it via a save).
    var lastRandomVariationIndex: Int {
        get { UserDefaults.standard.object(forKey: "lastRandomVariationIndex") as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: "lastRandomVariationIndex") }
    }

    var palette: [PaletteSwatch] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "paletteSwatches"),
                  let decoded = try? JSONDecoder().decode([PaletteSwatch].self, from: data),
                  !decoded.isEmpty else {
                return PaletteSwatch.defaultPalette
            }

            return Array(decoded.prefix(8))
        }
        set {
            let normalized = Array(newValue.prefix(8))
            guard !normalized.isEmpty,
                  let data = try? JSONEncoder().encode(normalized) else {
                return
            }

            UserDefaults.standard.set(data, forKey: "paletteSwatches")
        }
    }

    /// The named palette shelf — the user's saves plus the preinstalled
    /// palettes, which PaletteLibrary seeds in here on first run. Distinct from
    /// the active `palette` (which always persists on its own) — these are
    /// named bookmarks the user can return to after editing.
    var savedPalettes: [SavedPalette] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "savedPalettes"),
                  let decoded = try? JSONDecoder().decode([SavedPalette].self, from: data) else {
                return []
            }

            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: "savedPalettes")
        }
    }

    /// The single unnamed working palette — see `PaletteLibrary`. Holds an edit
    /// that matches no preset, so switching away (the presets dropdown, or `c`
    /// in the overlay) can't drop it. Writing nil, or an empty palette, clears
    /// the slot.
    var stashedPalette: [PaletteSwatch]? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "stashedPalette"),
                  let decoded = try? JSONDecoder().decode([PaletteSwatch].self, from: data),
                  !decoded.isEmpty else {
                return nil
            }

            return Array(decoded.prefix(8))
        }
        set {
            guard let newValue else {
                UserDefaults.standard.removeObject(forKey: "stashedPalette")
                return
            }

            let normalized = Array(newValue.prefix(8))
            guard !normalized.isEmpty,
                  let data = try? JSONEncoder().encode(normalized) else {
                UserDefaults.standard.removeObject(forKey: "stashedPalette")
                return
            }

            UserDefaults.standard.set(data, forKey: "stashedPalette")
        }
    }

    /// Built-in presets the user deleted from the shelf, by name. Names (not
    /// indices) so adding or reordering a built-in can't shift which ones stay
    /// hidden.
    /// Legacy (pre-unified-shelf): built-ins the user had "deleted" under the
    /// old hide-built-ins model. Read once by PaletteLibrary's seeding
    /// migration, then cleared. Keep for migration; don't build on it.
    var hiddenPresetNames: [String] {
        get { UserDefaults.standard.stringArray(forKey: "hiddenPresetNames") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "hiddenPresetNames") }
    }

    var horizontalMirrorMode: HorizontalMirrorMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: "horizontalMirrorMode"),
               let mode = HorizontalMirrorMode(rawValue: raw) {
                return mode
            }
            if UserDefaults.standard.object(forKey: "mirrorHorizontal") as? Bool == true {
                return .leftToRight
            }
            return .none
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "horizontalMirrorMode") }
    }

    var verticalMirrorMode: VerticalMirrorMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: "verticalMirrorMode"),
               let mode = VerticalMirrorMode(rawValue: raw) {
                return mode
            }
            if UserDefaults.standard.object(forKey: "mirrorVertical") as? Bool == true {
                return .topToBottom
            }
            return .none
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "verticalMirrorMode") }
    }

    var filenameFormat: String {
        get { UserDefaults.standard.string(forKey: "filenameFormat") ?? "dab_{date}_{time}" }
        set { UserDefaults.standard.set(newValue, forKey: "filenameFormat") }
    }

    var saveDirectory: URL {
        get {
            if let bookmark = UserDefaults.standard.data(forKey: "saveDirectoryBookmark") {
                var isStale = false
                if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    // A resolved-but-stale bookmark still points at a valid URL
                    // (common after OS updates or the directory moving). Regenerate
                    // and persist a fresh bookmark so the chosen directory doesn't
                    // silently revert to Desktop on a later launch.
                    if isStale {
                        let didAccess = url.startAccessingSecurityScopedResource()
                        if let refreshed = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                            UserDefaults.standard.set(refreshed, forKey: "saveDirectoryBookmark")
                        }
                        if didAccess { url.stopAccessingSecurityScopedResource() }
                    }
                    return url
                }
            }
            // Only reached when there is no bookmark or it fails to resolve entirely.
            // homeDirectoryForCurrentUser is non-optional and always available, so
            // it removes the crash path on systems where the desktop URL list is empty.
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
        }
        set {
            if let bookmark = try? newValue.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(bookmark, forKey: "saveDirectoryBookmark")
            }
        }
    }

    var hotkeyKeyCode: UInt32 {
        get { UInt32(UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? Int ?? 50) } // 50 = '`'
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyKeyCode") }
    }

    var hotkeyModifiers: UInt32 {
        get { UInt32(UserDefaults.standard.object(forKey: "hotkeyModifiers") as? Int ?? 0x1200) } // Control+Shift (controlKey 0x1000 | shiftKey 0x200)
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

    /// Whether `keyCode` maps to a known, bindable key. Used by the hotkey
    /// recorder to reject pure-modifier or otherwise unmappable keycodes before
    /// committing a binding the user couldn't read back or rely on.
    static func isKnownKeyCode(_ keyCode: UInt32) -> Bool {
        keyCodeToString(keyCode) != "Key\(keyCode)"
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
