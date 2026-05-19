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
        case .otsu:
            return applyAutoBands(colors: colors, palette: palette)
        case .adaptive:
            return applyAdaptive(colors: colors, gridSize: gridSize, palette: palette, threshold: threshold)
        case .contrastBoost:
            return applyContrastBoost(colors: colors, palette: palette, threshold: threshold)
        case .cleanThreshold:
            return applyClean(colors: colors, gridSize: gridSize, palette: palette, threshold: threshold)
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
        colors.map {
            paletteCell(
                bandIndex(for: $0.brightness, paletteCount: palette.count, threshold: threshold),
                palette: palette
            )
        }
    }

    // MARK: - 3. Auto Bands

    private static func applyAutoBands(colors: [PixelColor], palette: [PaletteSwatch]) -> [GridCell] {
        guard !colors.isEmpty else { return [] }
        guard palette.count > 1 else {
            return Array(repeating: paletteCell(0, palette: palette), count: colors.count)
        }

        if palette.count == 2 {
            let threshold = otsuThreshold(colors.map(\.brightness))
            return applyThresholdBands(colors: colors, palette: palette, threshold: threshold)
        }

        let brightnessValues = colors.map(\.brightness)
        let clusterCount = min(palette.count, max(1, brightnessValues.count))
        var centers = (0..<clusterCount).map { (Float($0) + 0.5) / Float(clusterCount) }
        var assignments = Array(repeating: 0, count: brightnessValues.count)

        for _ in 0..<10 {
            for (index, brightness) in brightnessValues.enumerated() {
                assignments[index] = centers.indices.min { lhs, rhs in
                    abs(brightness - centers[lhs]) < abs(brightness - centers[rhs])
                } ?? 0
            }

            var sums = Array(repeating: Float(0), count: clusterCount)
            var counts = Array(repeating: Float(0), count: clusterCount)
            for (index, assignment) in assignments.enumerated() {
                sums[assignment] += brightnessValues[index]
                counts[assignment] += 1
            }

            for index in centers.indices where counts[index] > 0 {
                centers[index] = sums[index] / counts[index]
            }
        }

        let rankedClusters = centers.indices.sorted { centers[$0] < centers[$1] }
        var clusterToPaletteIndex = Array(repeating: 0, count: clusterCount)
        for (rank, cluster) in rankedClusters.enumerated() {
            clusterToPaletteIndex[cluster] = min(rank, palette.count - 1)
        }

        return assignments.map { paletteCell(clusterToPaletteIndex[$0], palette: palette) }
    }

    private static func otsuThreshold(_ brightness: [Float]) -> Float {
        guard !brightness.isEmpty else { return 0.5 }

        let binCount = 256
        var histogram = [Int](repeating: 0, count: binCount)
        for value in brightness {
            let bin = min(binCount - 1, max(0, Int(clamped(value) * Float(binCount - 1))))
            histogram[bin] += 1
        }

        let total = brightness.count
        var sumAll: Float = 0
        for i in 0..<binCount {
            sumAll += Float(i) * Float(histogram[i])
        }

        var sumBackground: Float = 0
        var backgroundWeight = 0
        var maxVariance: Float = 0
        var bestThreshold = 0

        for i in 0..<binCount {
            backgroundWeight += histogram[i]
            if backgroundWeight == 0 { continue }

            let foregroundWeight = total - backgroundWeight
            if foregroundWeight == 0 { break }

            sumBackground += Float(i) * Float(histogram[i])
            let backgroundMean = sumBackground / Float(backgroundWeight)
            let foregroundMean = (sumAll - sumBackground) / Float(foregroundWeight)
            let meanDifference = backgroundMean - foregroundMean
            let variance = Float(backgroundWeight) * Float(foregroundWeight) * meanDifference * meanDifference

            if variance > maxVariance {
                maxVariance = variance
                bestThreshold = i
            }
        }

        return Float(bestThreshold) / Float(binCount - 1)
    }

    // MARK: - 4. Adaptive

    private static func applyAdaptive(
        colors: [PixelColor],
        gridSize: Int,
        palette: [PaletteSwatch],
        threshold: Float
    ) -> [GridCell] {
        let count = gridSize * gridSize
        guard gridSize > 0, colors.count >= count else {
            return applyThresholdBands(colors: colors, palette: palette, threshold: threshold)
        }

        let brightness = Array(colors.prefix(count)).map(\.brightness)
        var result = [GridCell](repeating: .transparent, count: count)
        let radius = max(1, min(3, gridSize / 6))

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                var sum: Float = 0
                var samples: Float = 0

                for dr in -radius...radius {
                    for dc in -radius...radius {
                        let r = row + dr
                        let c = col + dc
                        if r >= 0, r < gridSize, c >= 0, c < gridSize {
                            sum += brightness[r * gridSize + c]
                            samples += 1
                        }
                    }
                }

                let localMean = samples > 0 ? sum / samples : 0.5
                let localBrightness = clamped(0.5 + ((brightness[row * gridSize + col] - localMean) * 1.4))
                let index = bandIndex(for: localBrightness, paletteCount: palette.count, threshold: threshold)
                result[row * gridSize + col] = paletteCell(index, palette: palette)
            }
        }

        return result
    }

    // MARK: - 5. Contrast

    private static func applyContrastBoost(colors: [PixelColor], palette: [PaletteSwatch], threshold: Float) -> [GridCell] {
        guard !colors.isEmpty else { return [] }

        let sortedBrightness = colors.map(\.brightness).sorted()
        let low = percentile(in: sortedBrightness, p: 0.10)
        let high = percentile(in: sortedBrightness, p: 0.90)
        let normalized = colors.map { $0.contrastNormalized(low: low, high: high) }
        return applyColorMatch(colors: normalized, palette: palette, threshold: threshold)
    }

    private static func percentile(in sorted: [Float], p: Float) -> Float {
        guard let last = sorted.indices.last else { return 0.5 }
        let index = Int(round(Float(last) * clamped(p)))
        return sorted[index]
    }

    // MARK: - 6. Clean

    private static func applyClean(
        colors: [PixelColor],
        gridSize: Int,
        palette: [PaletteSwatch],
        threshold: Float
    ) -> [GridCell] {
        let count = gridSize * gridSize
        guard gridSize > 0, colors.count >= count else {
            return applyColorMatch(colors: colors, palette: palette, threshold: threshold)
        }

        let base = applyColorMatch(
            colors: Array(colors.prefix(count)),
            palette: palette,
            threshold: threshold
        )
        let passes = gridSize <= 10 ? 2 : 1
        return applyMajorityCleanup(cells: base, gridSize: gridSize, passes: passes)
    }

    private static func applyMajorityCleanup(cells: [GridCell], gridSize: Int, passes: Int) -> [GridCell] {
        var current = cells

        for _ in 0..<passes {
            var next = current

            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    var counts: [GridCell: Int] = [:]

                    for dr in -1...1 {
                        for dc in -1...1 {
                            let r = row + dr
                            let c = col + dc
                            guard r >= 0, r < gridSize, c >= 0, c < gridSize else { continue }
                            counts[current[r * gridSize + c], default: 0] += 1
                        }
                    }

                    if let winner = counts.max(by: { $0.value < $1.value })?.key {
                        next[row * gridSize + col] = winner
                    }
                }
            }

            current = next
        }

        return current
    }

    // MARK: - 7. Outline

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
