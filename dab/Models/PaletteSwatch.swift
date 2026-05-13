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
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

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
}
