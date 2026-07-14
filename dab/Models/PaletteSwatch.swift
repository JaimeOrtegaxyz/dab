import Foundation

struct PixelColor: Codable, Hashable {
    var red: Float
    var green: Float
    var blue: Float

    init(red: Float, green: Float, blue: Float) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        // Accept common shorthand and alpha forms: expand 3-digit #RGB to
        // #RRGGBB, and drop the alpha byte from 8-digit #RRGGBBAA (PixelColor
        // has no alpha channel).
        switch cleaned.count {
        case 3:
            cleaned = cleaned.map { "\($0)\($0)" }.joined()
        case 8:
            cleaned = String(cleaned.prefix(6))
        default:
            break
        }

        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            return nil
        }

        self.init(
            red: Float((value >> 16) & 0xff) / 255.0,
            green: Float((value >> 8) & 0xff) / 255.0,
            blue: Float(value & 0xff) / 255.0
        )
    }

    var brightness: Float {
        (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    }

    var hexString: String {
        let r = Int(round(Self.clamp(red) * 255.0))
        let g = Int(round(Self.clamp(green) * 255.0))
        let b = Int(round(Self.clamp(blue) * 255.0))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    func distanceSquared(to other: PixelColor) -> Float {
        let redMean = (red + other.red) / 2.0
        let redWeight = 2.0 + redMean
        let greenWeight: Float = 4.0
        let blueWeight = 3.0 - redMean
        let dr = red - other.red
        let dg = green - other.green
        let db = blue - other.blue
        return (redWeight * dr * dr) + (greenWeight * dg * dg) + (blueWeight * db * db)
    }

    func contrastNormalized(low: Float, high: Float) -> PixelColor {
        let range = high - low
        guard range > 0.001 else { return self }

        return PixelColor(
            red: (red - low) / range,
            green: (green - low) / range,
            blue: (blue - low) / range
        )
    }

    private static func clamp(_ value: Float) -> Float {
        min(1.0, max(0.0, value))
    }
}

struct PaletteSwatch: Codable, Hashable, Identifiable {
    var id: UUID
    var color: PixelColor
    var isTransparent: Bool

    init(id: UUID = UUID(), color: PixelColor, isTransparent: Bool = false) {
        self.id = id
        self.color = color
        self.isTransparent = isTransparent
    }

    static let defaultPalette: [PaletteSwatch] = [
        PaletteSwatch(color: PixelColor(hex: "#000000")!),
        PaletteSwatch(color: PixelColor(hex: "#17AE65")!),
        PaletteSwatch(color: PixelColor(hex: "#F14729")!),
        PaletteSwatch(color: PixelColor(hex: "#FDE012")!),
        PaletteSwatch(color: PixelColor(hex: "#006AFF")!),
    ]

    static let blackTransparentPalette: [PaletteSwatch] = [
        PaletteSwatch(color: PixelColor(hex: "#000000")!),
        PaletteSwatch(color: PixelColor(hex: "#000000")!, isTransparent: true),
    ]

    /// Builds an opaque palette from hex strings (dev-authored, so force-unwrap
    /// is fine — same as the literals above). Index 0 is the Blobs grout.
    private static func hexes(_ values: String...) -> [PaletteSwatch] {
        values.map { PaletteSwatch(color: PixelColor(hex: $0)!) }
    }

    /// The curated preset shelf. Names lean playful over descriptive; palettes
    /// span deliberately different moods (bold primaries, arcade neon, glossy
    /// aero, DMG greens, a brown-anchored candy set, and an ink stencil). #1 is
    /// always the grout, so grout choice is part of each palette's look.
    static let presets: [PalettePreset] = [
        // The colorful house set (still the app default) — colored dots on black,
        // exactly a Lite-Brite peg board.
        PalettePreset(name: "lite brite", swatches: defaultPalette),
        // Full 8-swatch neon cabinet on black.
        PalettePreset(name: "insert coin", swatches: hexes(
            "#000000", "#FF004D", "#FF8A00", "#FFE400",
            "#14FF72", "#00D9FF", "#7A5CFF", "#FF3EC9"
        )),
        // Solid chocolate grout surrounded by candy pops (not earthy neighbours).
        PalettePreset(name: "choco taco", swatches: hexes(
            "#5C3A21", "#FFD23F", "#FF5DA2", "#12D8B0", "#7B61FF"
        )),
        // Ink + one see-through swatch: silhouettes onto the desktop.
        PalettePreset(name: "ghosted", swatches: blackTransparentPalette),
    ]
}

/// A named palette on the presets shelf.
struct PalettePreset: Identifiable {
    var name: String
    var swatches: [PaletteSwatch]
    var id: String { name }
}

/// A palette the user saved. Same shape as a built-in `PalettePreset`, but
/// `Codable` because these are persisted to `UserDefaults` (via
/// `AppSettings.savedPalettes`) rather than declared in code. `id` is a stable
/// UUID so the presets dropdown's `ForEach` survives renames; matching against
/// the live palette is by swatches, and the chip shows `name`.
struct SavedPalette: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var swatches: [PaletteSwatch]

    init(id: UUID = UUID(), name: String, swatches: [PaletteSwatch]) {
        self.id = id
        self.name = name
        self.swatches = swatches
    }
}
