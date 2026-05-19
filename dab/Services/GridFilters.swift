import Foundation

enum GridFilters {
    static func apply(
        _ mode: FilterMode,
        colors: [PixelColor],
        gridSize: Int,
        palette: [PaletteSwatch],
        threshold: Float,
        paletteVotes: [Int?]? = nil
    ) -> [GridCell] {
        let palette = normalize(palette: palette)

        switch mode {
        case .colorMatch:
            return applyColorMatch(
                colors: colors,
                palette: palette,
                threshold: threshold,
                paletteVotes: paletteVotes
            )
        case .threshold:
            return applyThresholdBands(colors: colors, palette: palette, threshold: threshold)
        case .edgeDetect:
            return applyOutline(colors: colors, gridSize: gridSize, palette: palette, threshold: threshold)
        }
    }

    /// Public so callers can normalize the palette once before sampling and
    /// then pass the *same* normalized palette into `apply` — keeping vote
    /// indices and filter indices aligned.
    static func normalize(palette: [PaletteSwatch]) -> [PaletteSwatch] {
        let trimmed = Array(palette.prefix(8))
        return trimmed.isEmpty ? PaletteSwatch.defaultPalette : trimmed
    }

    private static func clamped(_ value: Float, min minValue: Float = 0, max maxValue: Float = 1) -> Float {
        Swift.min(maxValue, Swift.max(minValue, value))
    }

    private static func paletteCell(_ index: Int, palette: [PaletteSwatch]) -> GridCell {
        guard !palette.isEmpty else { return .transparent }
        return .palette(min(max(index, 0), palette.count - 1))
    }

    private static func bandIndex(for brightness: Float, paletteCount: Int, threshold: Float) -> Int {
        guard paletteCount > 1 else { return 0 }

        let adjusted = clamped(brightness + (0.5 - threshold))
        let rawIndex = Int(floor(adjusted * Float(paletteCount)))
        return min(max(rawIndex, 0), paletteCount - 1)
    }

    private static func transparentBandIndex(for color: PixelColor, palette: [PaletteSwatch], threshold: Float) -> Int? {
        let index = bandIndex(for: color.brightness, paletteCount: palette.count, threshold: threshold)
        return palette[index].isTransparent ? index : nil
    }

    private static func nearestColorIndex(for color: PixelColor, palette: [PaletteSwatch]) -> Int? {
        palette.indices
            .filter { !palette[$0].isTransparent }
            .min { lhs, rhs in
                color.distanceSquared(to: palette[lhs].color) < color.distanceSquared(to: palette[rhs].color)
            }
    }

    // MARK: - 1. Color Match

    private static func applyColorMatch(
        colors: [PixelColor],
        palette: [PaletteSwatch],
        threshold: Float,
        paletteVotes: [Int?]? = nil
    ) -> [GridCell] {
        colors.enumerated().map { index, color in
            // Transparent-band assignment is brightness-driven and stays as
            // it was: cells whose averaged brightness falls into the band
            // occupied by a transparent swatch become transparent.
            if let transparentIndex = transparentBandIndex(for: color, palette: palette, threshold: threshold) {
                return paletteCell(transparentIndex, palette: palette)
            }

            // If the sampling layer voted on this cell, trust the vote — it
            // reflects per-source-pixel matches and avoids the phantom-color
            // artifact you'd get by matching an averaged blend.
            if let votes = paletteVotes, index < votes.count, let voteIndex = votes[index] {
                return paletteCell(voteIndex, palette: palette)
            }

            // Fallback: no vote (zero source pixels for this cell, or the
            // caller didn't provide votes). Match against the averaged color.
            guard let nearest = nearestColorIndex(for: color, palette: palette) else {
                return paletteCell(0, palette: palette)
            }

            return paletteCell(nearest, palette: palette)
        }
    }

    // MARK: - 2. Threshold Bands

    private static func applyThresholdBands(colors: [PixelColor], palette: [PaletteSwatch], threshold: Float) -> [GridCell] {
        // Sort indices by brightness so band 0 = darkest swatch, band N-1 = brightest.
        // The user's palette storage order is left untouched; this mapping only applies
        // inside this filter so the slider behaves predictably regardless of how the
        // user has arranged their palette in the editor.
        let bandToPalette = palette.indices.sorted {
            palette[$0].color.brightness < palette[$1].color.brightness
        }

        guard !bandToPalette.isEmpty else { return colors.map { _ in .transparent } }

        return colors.map { color in
            let band = bandIndex(for: color.brightness, paletteCount: palette.count, threshold: threshold)
            let clamped = min(band, bandToPalette.count - 1)
            return paletteCell(bandToPalette[clamped], palette: palette)
        }
    }

    // MARK: - 3. Outline

    private static func applyOutline(
        colors: [PixelColor],
        gridSize: Int,
        palette: [PaletteSwatch],
        threshold: Float
    ) -> [GridCell] {
        let count = gridSize * gridSize
        guard gridSize > 0, colors.count >= count else {
            return Array(repeating: .transparent, count: max(colors.count, 0))
        }

        let brightness = Array(colors.prefix(count)).map(\.brightness)

        func pixel(_ r: Int, _ c: Int) -> Float {
            let r = min(max(r, 0), gridSize - 1)
            let c = min(max(c, 0), gridSize - 1)
            return brightness[r * gridSize + c]
        }

        var edges = [Float](repeating: 0, count: count)
        var maxEdge: Float = 0

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let gx = -pixel(row - 1, col - 1) + pixel(row - 1, col + 1)
                    - 2 * pixel(row, col - 1) + 2 * pixel(row, col + 1)
                    - pixel(row + 1, col - 1) + pixel(row + 1, col + 1)

                let gy = -pixel(row - 1, col - 1) - 2 * pixel(row - 1, col) - pixel(row - 1, col + 1)
                    + pixel(row + 1, col - 1) + 2 * pixel(row + 1, col) + pixel(row + 1, col + 1)

                let magnitude = sqrt(gx * gx + gy * gy)
                edges[row * gridSize + col] = magnitude
                maxEdge = max(maxEdge, magnitude)
            }
        }

        let backgroundIndex = palette.indices.first { palette[$0].isTransparent }
            ?? palette.indices.filter { !palette[$0].isTransparent }.max {
                palette[$0].color.brightness < palette[$1].color.brightness
            }
            ?? 0

        guard maxEdge > 0 else {
            return Array(repeating: paletteCell(backgroundIndex, palette: palette), count: count)
        }

        let edgeThreshold = 1.0 - threshold
        return edges.enumerated().map { index, edge in
            guard (edge / maxEdge) > edgeThreshold else {
                return paletteCell(backgroundIndex, palette: palette)
            }

            guard let nearest = nearestColorIndex(for: colors[index], palette: palette) else {
                return paletteCell(0, palette: palette)
            }

            return paletteCell(nearest, palette: palette)
        }
    }
}
