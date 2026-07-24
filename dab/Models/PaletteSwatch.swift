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

    /// Scales chroma around the pixel's own luma, leaving perceived brightness
    /// alone. `gain` 1 is the identity; 0 collapses to gray; above 1 saturates.
    ///
    /// Color Match's spread control runs through here: saturating pushes cells
    /// onto swatches that were never the nearest match before (more of the
    /// palette shows up), desaturating funnels them onto the neutral swatches
    /// (the image flattens toward a few colors). Scaling around luma rather
    /// than mid-gray is deliberate — pulling toward 0.5 instead would drag
    /// darks and lights to the extremes and *reduce* the color variety this is
    /// meant to increase.
    func chromaScaled(_ gain: Float) -> PixelColor {
        guard gain != 1 else { return self }

        let luma = brightness
        return PixelColor(
            red: luma + (red - luma) * gain,
            green: luma + (green - luma) * gain,
            blue: luma + (blue - luma) * gain
        )
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

    /// Builds an opaque palette from hex strings (dev-authored, so force-unwrap
    /// is fine — same as the literals above). Index 0 is the Blobs grout.
    private static func hexes(_ values: String...) -> [PaletteSwatch] {
        values.map { PaletteSwatch(color: PixelColor(hex: $0)!) }
    }

    /// The curated preset shelf. Names lean playful over descriptive. The house
    /// set is five bold primaries; the rest are lifted from photographs, so they
    /// posterize coarsely and read as a mood rather than a reproduction. #1 is
    /// always the grout, so grout choice is part of each palette's look — each
    /// of these leads with its darkest color, and the swatches then climb in
    /// brightness so the Threshold and Halftone bands ramp dark-to-light.
    static let presets: [PalettePreset] = [
        // The colorful house set (still the app default) — colored dots on black,
        // exactly a Lite-Brite peg board.
        PalettePreset(name: "lite brite", swatches: defaultPalette),
        // Adidas Originals SL 72 RS campaign: navy tracksuit, rust locker doors,
        // carpet blue, skin, powder-blue walls.
        PalettePreset(name: "locker room", swatches: hexes(
            "#06286B", "#BD4527", "#3B829C", "#DA9678", "#B9E2F2"
        )),
        // Rafael Pavarotti's "Damiana" — gold and lavender against near-black,
        // the highest-contrast set on the shelf.
        PalettePreset(name: "damiana", swatches: hexes(
            "#040C05", "#ED980A", "#E6D8FA"
        )),
        // Martin Parr's Benidorm — royal blue, sunburnt red, the azure of the
        // towel and sunglasses, hot sand. Pushed past the film scan's own
        // saturation to lite brite levels; the flash-lit source earns it.
        PalettePreset(name: "sunburn", swatches: hexes(
            "#0033B8", "#E12A1C", "#1E8CF0", "#FFC01F"
        )),
        // Bouroullec's Alcova glass for Wonderglass — bottle green, amber, and
        // the white of blown glass held to the light.
        PalettePreset(name: "hot glass", swatches: hexes(
            "#336234", "#FF9601", "#E9E9E8"
        )),
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
