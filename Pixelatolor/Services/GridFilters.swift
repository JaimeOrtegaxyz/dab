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
        case .edgeDetect:
            return applyEdgeDetect(brightness: brightness, gridSize: gridSize, threshold: threshold)
        case .floydSteinberg:
            return applyFloydSteinberg(brightness: brightness, gridSize: gridSize)
        case .bayerDither:
            return applyBayerDither(brightness: brightness, gridSize: gridSize)
        }
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
        let radius = 2 // 5x5 neighborhood
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

    // MARK: - 4. Edge Detect (Sobel)

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

    // MARK: - 5. Floyd-Steinberg Dithering

    private static func applyFloydSteinberg(brightness: [Float], gridSize: Int) -> [Bool] {
        let count = gridSize * gridSize
        guard gridSize > 0, brightness.count >= count else {
            return brightness.map { $0 < 0.5 }
        }

        var buffer = Array(brightness.prefix(count))
        var result = [Bool](repeating: false, count: count)

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let idx = row * gridSize + col
                let oldVal = buffer[idx]
                let newVal: Float = oldVal < 0.5 ? 0.0 : 1.0
                result[idx] = newVal == 0.0 // black
                let error = oldVal - newVal

                if col + 1 < gridSize {
                    buffer[idx + 1] += error * 7.0 / 16.0
                }
                if row + 1 < gridSize {
                    if col > 0 {
                        buffer[(row + 1) * gridSize + (col - 1)] += error * 3.0 / 16.0
                    }
                    buffer[(row + 1) * gridSize + col] += error * 5.0 / 16.0
                    if col + 1 < gridSize {
                        buffer[(row + 1) * gridSize + (col + 1)] += error * 1.0 / 16.0
                    }
                }
            }
        }

        return result
    }

    // MARK: - 6. Bayer Ordered Dithering (4x4)

    private static let bayerMatrix: [Float] = [
         0.0 / 16,  8.0 / 16,  2.0 / 16, 10.0 / 16,
        12.0 / 16,  4.0 / 16, 14.0 / 16,  6.0 / 16,
         3.0 / 16, 11.0 / 16,  1.0 / 16,  9.0 / 16,
        15.0 / 16,  7.0 / 16, 13.0 / 16,  5.0 / 16,
    ]

    private static func applyBayerDither(brightness: [Float], gridSize: Int) -> [Bool] {
        let count = gridSize * gridSize
        guard gridSize > 0, brightness.count >= count else {
            return brightness.map { $0 < 0.5 }
        }

        var result = [Bool](repeating: false, count: count)
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let idx = row * gridSize + col
                let t = bayerMatrix[(row % 4) * 4 + (col % 4)]
                result[idx] = brightness[idx] < t
            }
        }

        return result
    }
}
