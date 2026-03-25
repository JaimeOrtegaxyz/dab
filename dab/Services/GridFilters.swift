import Foundation

enum GridFilters {
    static func apply(_ mode: FilterMode, brightness: [Float], gridSize: Int, threshold: Float) -> [Bool] {
        switch mode {
        case .threshold:
            return applyThreshold(brightness: brightness, threshold: threshold)
        case .otsu:
            return applyOtsu(brightness: brightness)
        case .adaptive:
            return applyAdaptive(brightness: brightness, gridSize: gridSize)
        case .contrastBoost:
            return applyContrastBoost(brightness: brightness, threshold: threshold)
        case .cleanThreshold:
            return applyCleanThreshold(brightness: brightness, gridSize: gridSize, threshold: threshold)
        case .edgeDetect:
            return applyEdgeDetect(brightness: brightness, gridSize: gridSize, threshold: threshold)
        case .floydSteinberg:
            return applyFloydSteinberg(brightness: brightness, gridSize: gridSize, threshold: threshold)
        case .bayerDither:
            return applyBayerDither(brightness: brightness, gridSize: gridSize, threshold: threshold)
        }
    }

    private static func clamped(_ value: Float, min minValue: Float = 0, max maxValue: Float = 1) -> Float {
        Swift.min(maxValue, Swift.max(minValue, value))
    }

    private static func percentile(in sorted: [Float], p: Float) -> Float {
        guard let last = sorted.indices.last else { return 0.5 }
        let index = Int(round(Float(last) * clamped(p)))
        return sorted[index]
    }

    private static func normalizeContrast(brightness: [Float]) -> [Float] {
        guard !brightness.isEmpty else { return [] }

        let sorted = brightness.sorted()
        let low = percentile(in: sorted, p: 0.10)
        let high = percentile(in: sorted, p: 0.90)
        let range = high - low

        guard range > 0.001 else {
            return brightness.map { clamped($0) }
        }

        return brightness.map { clamped(($0 - low) / range) }
    }

    // MARK: - 1. Threshold (existing behavior)

    private static func applyThreshold(brightness: [Float], threshold: Float) -> [Bool] {
        brightness.map { $0 < threshold }
    }

    // MARK: - 2. Otsu (auto threshold)

    private static func applyOtsu(brightness: [Float]) -> [Bool] {
        guard !brightness.isEmpty else { return [] }

        let binCount = 256
        var histogram = [Int](repeating: 0, count: binCount)
        for b in brightness {
            let bin = min(binCount - 1, max(0, Int(b * Float(binCount - 1))))
            histogram[bin] += 1
        }

        let total = brightness.count
        var sumAll: Float = 0
        for i in 0..<binCount {
            sumAll += Float(i) * Float(histogram[i])
        }

        var sumB: Float = 0
        var wB = 0
        var maxVariance: Float = 0
        var bestThreshold = 0

        for i in 0..<binCount {
            wB += histogram[i]
            if wB == 0 { continue }
            let wF = total - wB
            if wF == 0 { break }

            sumB += Float(i) * Float(histogram[i])
            let meanB = sumB / Float(wB)
            let meanF = (sumAll - sumB) / Float(wF)
            let variance = Float(wB) * Float(wF) * (meanB - meanF) * (meanB - meanF)

            if variance > maxVariance {
                maxVariance = variance
                bestThreshold = i
            }
        }

        let autoThreshold = Float(bestThreshold) / Float(binCount - 1)
        return brightness.map { $0 < autoThreshold }
    }

    // MARK: - 3. Adaptive (Sauvola)

    private static func applyAdaptive(brightness: [Float], gridSize: Int) -> [Bool] {
        let count = gridSize * gridSize
        guard gridSize > 0, brightness.count >= count else {
            return brightness.map { $0 < 0.5 }
        }

        var result = [Bool](repeating: false, count: count)
        let radius = max(1, min(3, gridSize / 6))
        let k: Float = 0.2
        let maxStdDev: Float = 0.5

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                var sum: Float = 0
                var sumSq: Float = 0
                var n: Float = 0

                for dr in -radius...radius {
                    for dc in -radius...radius {
                        let r = row + dr
                        let c = col + dc
                        if r >= 0, r < gridSize, c >= 0, c < gridSize {
                            let val = brightness[r * gridSize + c]
                            sum += val
                            sumSq += val * val
                            n += 1
                        }
                    }
                }

                let mean = sum / n
                let variance = (sumSq / n) - (mean * mean)
                let stddev = sqrt(max(0, variance))
                let localThreshold = mean * (1.0 + k * (stddev / maxStdDev - 1.0))

                result[row * gridSize + col] = brightness[row * gridSize + col] < localThreshold
            }
        }

        return result
    }

    // MARK: - 4. Auto Contrast

    private static func applyContrastBoost(brightness: [Float], threshold: Float) -> [Bool] {
        applyThreshold(brightness: normalizeContrast(brightness: brightness), threshold: threshold)
    }

    // MARK: - 5. Cleanup Threshold

    private static func applyCleanThreshold(brightness: [Float], gridSize: Int, threshold: Float) -> [Bool] {
        let count = gridSize * gridSize
        guard gridSize > 0, brightness.count >= count else {
            return brightness.map { $0 < threshold }
        }

        let base = applyThreshold(
            brightness: normalizeContrast(brightness: Array(brightness.prefix(count))),
            threshold: threshold
        )

        let passes = gridSize <= 10 ? 2 : 1
        return applyMajorityCleanup(cells: base, gridSize: gridSize, passes: passes)
    }

    private static func applyMajorityCleanup(cells: [Bool], gridSize: Int, passes: Int) -> [Bool] {
        var current = cells

        for _ in 0..<passes {
            var next = current

            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    var blackCount = 0
                    var totalCount = 0

                    for dr in -1...1 {
                        for dc in -1...1 {
                            let r = row + dr
                            let c = col + dc
                            guard r >= 0, r < gridSize, c >= 0, c < gridSize else { continue }
                            totalCount += 1
                            if current[r * gridSize + c] {
                                blackCount += 1
                            }
                        }
                    }

                    let whiteCount = totalCount - blackCount
                    let index = row * gridSize + col
                    if blackCount > whiteCount {
                        next[index] = true
                    } else if whiteCount > blackCount {
                        next[index] = false
                    } else {
                        next[index] = current[index]
                    }
                }
            }

            current = next
        }

        return current
    }

    // MARK: - 6. Edge Detect (Sobel)

    private static func applyEdgeDetect(brightness: [Float], gridSize: Int, threshold: Float) -> [Bool] {
        let count = gridSize * gridSize
        guard gridSize > 0, brightness.count >= count else {
            return [Bool](repeating: false, count: max(brightness.count, 0))
        }

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

        guard maxEdge > 0 else { return [Bool](repeating: false, count: count) }
        return edges.map { ($0 / maxEdge) > (1.0 - threshold) }
    }

    // MARK: - 7. Floyd-Steinberg Dithering

    private static func applyFloydSteinberg(brightness: [Float], gridSize: Int, threshold: Float) -> [Bool] {
        let count = gridSize * gridSize
        guard gridSize > 0, brightness.count >= count else {
            return brightness.map { $0 < threshold }
        }

        var buffer = Array(brightness.prefix(count))
        var result = [Bool](repeating: false, count: count)

        func addError(row: Int, col: Int, error: Float, weight: Float) {
            guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }
            let index = row * gridSize + col
            buffer[index] = clamped(buffer[index] + error * weight)
        }

        for row in 0..<gridSize {
            if row.isMultiple(of: 2) {
                for col in 0..<gridSize {
                    let idx = row * gridSize + col
                    let oldVal = buffer[idx]
                    let newVal: Float = oldVal < threshold ? 0.0 : 1.0
                    result[idx] = newVal == 0.0
                    let error = oldVal - newVal

                    addError(row: row, col: col + 1, error: error, weight: 7.0 / 16.0)
                    addError(row: row + 1, col: col - 1, error: error, weight: 3.0 / 16.0)
                    addError(row: row + 1, col: col, error: error, weight: 5.0 / 16.0)
                    addError(row: row + 1, col: col + 1, error: error, weight: 1.0 / 16.0)
                }
            } else {
                for col in stride(from: gridSize - 1, through: 0, by: -1) {
                    let idx = row * gridSize + col
                    let oldVal = buffer[idx]
                    let newVal: Float = oldVal < threshold ? 0.0 : 1.0
                    result[idx] = newVal == 0.0
                    let error = oldVal - newVal

                    addError(row: row, col: col - 1, error: error, weight: 7.0 / 16.0)
                    addError(row: row + 1, col: col + 1, error: error, weight: 3.0 / 16.0)
                    addError(row: row + 1, col: col, error: error, weight: 5.0 / 16.0)
                    addError(row: row + 1, col: col - 1, error: error, weight: 1.0 / 16.0)
                }
            }
        }

        return result
    }

    // MARK: - 8. Bayer Ordered Dithering (4x4)

    private static let bayerMatrix: [Float] = [
         0.0 / 16,  8.0 / 16,  2.0 / 16, 10.0 / 16,
        12.0 / 16,  4.0 / 16, 14.0 / 16,  6.0 / 16,
         3.0 / 16, 11.0 / 16,  1.0 / 16,  9.0 / 16,
        15.0 / 16,  7.0 / 16, 13.0 / 16,  5.0 / 16,
    ]

    private static func applyBayerDither(brightness: [Float], gridSize: Int, threshold: Float) -> [Bool] {
        let count = gridSize * gridSize
        guard gridSize > 0, brightness.count >= count else {
            return brightness.map { $0 < threshold }
        }

        var result = [Bool](repeating: false, count: count)
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let idx = row * gridSize + col
                let patternThreshold = bayerMatrix[(row % 4) * 4 + (col % 4)] - 0.5
                let adjustedThreshold = clamped(threshold + patternThreshold)
                result[idx] = brightness[idx] < adjustedThreshold
            }
        }

        return result
    }
}
