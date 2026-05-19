import CoreGraphics
import CoreVideo

extension CVPixelBuffer {
    /// Computes an NxN grid of average sRGB colors from a region of a BGRA pixel buffer.
    func colorGrid(in region: CGRect, gridSize: Int) -> [PixelColor] {
        guard gridSize > 0 else {
            return []
        }

        let bufferWidth = CVPixelBufferGetWidth(self)
        let bufferHeight = CVPixelBufferGetHeight(self)
        let pixelFormat = CVPixelBufferGetPixelFormatType(self)

        guard bufferWidth > 0, bufferHeight > 0, pixelFormat == kCVPixelFormatType_32BGRA else {
            return Array(repeating: PixelColor(red: 0.5, green: 0.5, blue: 0.5), count: gridSize * gridSize)
        }

        let boundedRegion = region.integral.intersection(
            CGRect(x: 0, y: 0, width: bufferWidth, height: bufferHeight)
        )
        guard !boundedRegion.isNull, boundedRegion.width > 0, boundedRegion.height > 0 else {
            return Array(repeating: PixelColor(red: 0.5, green: 0.5, blue: 0.5), count: gridSize * gridSize)
        }

        let minX = Int(boundedRegion.minX)
        let minY = Int(boundedRegion.minY)
        let regionWidth = max(Int(boundedRegion.width), 1)
        let regionHeight = max(Int(boundedRegion.height), 1)

        CVPixelBufferLockBaseAddress(self, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else {
            return Array(repeating: PixelColor(red: 0.5, green: 0.5, blue: 0.5), count: gridSize * gridSize)
        }

        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let cellWidth = Float(regionWidth) / Float(gridSize)
        let cellHeight = Float(regionHeight) / Float(gridSize)

        var result = [PixelColor](repeating: PixelColor(red: 0, green: 0, blue: 0), count: gridSize * gridSize)

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let startX = minX + Int(Float(col) * cellWidth)
                let startY = minY + Int(Float(row) * cellHeight)
                let endX = min(minX + Int(Float(col + 1) * cellWidth), minX + regionWidth)
                let endY = min(minY + Int(Float(row + 1) * cellHeight), minY + regionHeight)

                var redSum: Float = 0
                var greenSum: Float = 0
                var blueSum: Float = 0
                var count: Int = 0

                for y in startY..<endY {
                    let rowOffset = y * bytesPerRow
                    for x in startX..<endX {
                        let pixelOffset = rowOffset + (x * 4)
                        blueSum += Float(bytes[pixelOffset])
                        greenSum += Float(bytes[pixelOffset + 1])
                        redSum += Float(bytes[pixelOffset + 2])
                        count += 1
                    }
                }

                if count > 0 {
                    let divisor = Float(count) * 255.0
                    result[row * gridSize + col] = PixelColor(
                        red: redSum / divisor,
                        green: greenSum / divisor,
                        blue: blueSum / divisor
                    )
                } else {
                    result[row * gridSize + col] = PixelColor(red: 0.5, green: 0.5, blue: 0.5)
                }
            }
        }

        return result
    }

    /// Computes an NxN grid of (RGB-averaged color, palette-vote winner) tuples
    /// from a region of a BGRA pixel buffer in a single locked pass.
    ///
    /// For each grid cell, every source pixel in the cell's region is:
    ///   1. Accumulated into a running RGB sum (used for the cell's average).
    ///   2. Matched against `votePalette` using the same perceptual redmean
    ///      distance the codebase uses elsewhere, casting one vote for the
    ///      nearest entry.
    ///
    /// The vote winner is decided by:
    ///   - highest vote count, then
    ///   - lowest summed distance among ties, then
    ///   - lowest `votePalette` index.
    ///
    /// Cells whose region contains zero source pixels return `nil` for their
    /// vote slot; callers can fall back to the averaged-color match for those.
    ///
    /// `votePalette` is expected to be the *non-transparent* swatch colors of
    /// the active palette, in any order. Vote indices map back into that array.
    func colorAndVoteGrid(
        in region: CGRect,
        gridSize: Int,
        votePalette: [PixelColor]
    ) -> (colors: [PixelColor], votes: [Int?]) {
        guard gridSize > 0 else {
            return ([], [])
        }

        let cellCount = gridSize * gridSize
        let fallbackColor = PixelColor(red: 0.5, green: 0.5, blue: 0.5)
        let fallback: (colors: [PixelColor], votes: [Int?]) = (
            colors: Array(repeating: fallbackColor, count: cellCount),
            votes: Array(repeating: nil, count: cellCount)
        )

        let bufferWidth = CVPixelBufferGetWidth(self)
        let bufferHeight = CVPixelBufferGetHeight(self)
        let pixelFormat = CVPixelBufferGetPixelFormatType(self)

        guard bufferWidth > 0, bufferHeight > 0, pixelFormat == kCVPixelFormatType_32BGRA else {
            return fallback
        }

        let boundedRegion = region.integral.intersection(
            CGRect(x: 0, y: 0, width: bufferWidth, height: bufferHeight)
        )
        guard !boundedRegion.isNull, boundedRegion.width > 0, boundedRegion.height > 0 else {
            return fallback
        }

        let minX = Int(boundedRegion.minX)
        let minY = Int(boundedRegion.minY)
        let regionWidth = max(Int(boundedRegion.width), 1)
        let regionHeight = max(Int(boundedRegion.height), 1)

        CVPixelBufferLockBaseAddress(self, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else {
            return fallback
        }

        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let cellWidth = Float(regionWidth) / Float(gridSize)
        let cellHeight = Float(regionHeight) / Float(gridSize)

        // Flatten the palette into parallel Float arrays so the inner loop
        // doesn't touch any Swift structs — pure arithmetic only.
        let paletteCount = votePalette.count
        var paletteR = [Float](repeating: 0, count: max(paletteCount, 1))
        var paletteG = [Float](repeating: 0, count: max(paletteCount, 1))
        var paletteB = [Float](repeating: 0, count: max(paletteCount, 1))
        for (index, color) in votePalette.enumerated() {
            paletteR[index] = color.red
            paletteG[index] = color.green
            paletteB[index] = color.blue
        }

        var colors = [PixelColor](repeating: PixelColor(red: 0, green: 0, blue: 0), count: cellCount)
        var votes = [Int?](repeating: nil, count: cellCount)

        // Per-cell scratch buffers, allocated once and reused across cells.
        var voteCounts = [Int](repeating: 0, count: max(paletteCount, 1))
        var voteDistances = [Float](repeating: 0, count: max(paletteCount, 1))

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let startX = minX + Int(Float(col) * cellWidth)
                let startY = minY + Int(Float(row) * cellHeight)
                let endX = min(minX + Int(Float(col + 1) * cellWidth), minX + regionWidth)
                let endY = min(minY + Int(Float(row + 1) * cellHeight), minY + regionHeight)

                var redSum: Float = 0
                var greenSum: Float = 0
                var blueSum: Float = 0
                var count: Int = 0

                if paletteCount > 0 {
                    for i in 0..<paletteCount {
                        voteCounts[i] = 0
                        voteDistances[i] = 0
                    }
                }

                for y in startY..<endY {
                    let rowOffset = y * bytesPerRow
                    for x in startX..<endX {
                        let pixelOffset = rowOffset + (x * 4)
                        let b = Float(bytes[pixelOffset])
                        let g = Float(bytes[pixelOffset + 1])
                        let r = Float(bytes[pixelOffset + 2])
                        redSum += r
                        greenSum += g
                        blueSum += b
                        count += 1

                        guard paletteCount > 0 else { continue }

                        // Per-pixel argmin over the palette using the same
                        // redmean weighting as PixelColor.distanceSquared.
                        // Values are in 0...255 here, not 0...1 — the formula
                        // is scale-invariant in argmin so we don't bother
                        // normalizing inside the hot loop.
                        let rNorm = r / 255.0
                        let gNorm = g / 255.0
                        let bNorm = b / 255.0

                        var bestIndex = 0
                        var bestDistance: Float = .infinity

                        for i in 0..<paletteCount {
                            let pr = paletteR[i]
                            let pg = paletteG[i]
                            let pb = paletteB[i]
                            let redMean = (rNorm + pr) * 0.5
                            let redWeight = 2.0 + redMean
                            let blueWeight = 3.0 - redMean
                            let dr = rNorm - pr
                            let dg = gNorm - pg
                            let db = bNorm - pb
                            let distance = (redWeight * dr * dr) + (4.0 * dg * dg) + (blueWeight * db * db)
                            if distance < bestDistance {
                                bestDistance = distance
                                bestIndex = i
                            }
                        }

                        voteCounts[bestIndex] += 1
                        voteDistances[bestIndex] += bestDistance
                    }
                }

                let cellIndex = row * gridSize + col
                if count > 0 {
                    let divisor = Float(count) * 255.0
                    colors[cellIndex] = PixelColor(
                        red: redSum / divisor,
                        green: greenSum / divisor,
                        blue: blueSum / divisor
                    )

                    if paletteCount > 0 {
                        var winnerIndex = -1
                        var winnerCount = -1
                        var winnerDistance: Float = .infinity
                        for i in 0..<paletteCount {
                            let c = voteCounts[i]
                            if c == 0 { continue }
                            if c > winnerCount {
                                winnerIndex = i
                                winnerCount = c
                                winnerDistance = voteDistances[i]
                            } else if c == winnerCount {
                                // Tie-break: lower summed distance wins; on a
                                // further tie, the lower palette index wins
                                // (i < winnerIndex is implicit since we
                                // iterate in order and only swap on strict
                                // distance improvement).
                                if voteDistances[i] < winnerDistance {
                                    winnerIndex = i
                                    winnerDistance = voteDistances[i]
                                }
                            }
                        }
                        votes[cellIndex] = winnerIndex >= 0 ? winnerIndex : nil
                    }
                } else {
                    colors[cellIndex] = fallbackColor
                    votes[cellIndex] = nil
                }
            }
        }

        return (colors, votes)
    }

    /// Computes an NxN grid of average brightness values from a region of a BGRA pixel buffer.
    /// Returns a flat array of size gridSize*gridSize with values 0.0 (black) to 1.0 (white).
    func brightnessGrid(in region: CGRect, gridSize: Int) -> [Float] {
        guard gridSize > 0 else {
            return []
        }

        let bufferWidth = CVPixelBufferGetWidth(self)
        let bufferHeight = CVPixelBufferGetHeight(self)
        let pixelFormat = CVPixelBufferGetPixelFormatType(self)

        guard bufferWidth > 0, bufferHeight > 0, pixelFormat == kCVPixelFormatType_32BGRA else {
            return Array(repeating: 0.5, count: gridSize * gridSize)
        }

        let boundedRegion = region.integral.intersection(
            CGRect(x: 0, y: 0, width: bufferWidth, height: bufferHeight)
        )
        guard !boundedRegion.isNull, boundedRegion.width > 0, boundedRegion.height > 0 else {
            return Array(repeating: 0.5, count: gridSize * gridSize)
        }

        let minX = Int(boundedRegion.minX)
        let minY = Int(boundedRegion.minY)
        let regionWidth = max(Int(boundedRegion.width), 1)
        let regionHeight = max(Int(boundedRegion.height), 1)

        CVPixelBufferLockBaseAddress(self, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else {
            return Array(repeating: 0.5, count: gridSize * gridSize)
        }

        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let cellWidth = Float(regionWidth) / Float(gridSize)
        let cellHeight = Float(regionHeight) / Float(gridSize)

        var result = [Float](repeating: 0, count: gridSize * gridSize)

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let startX = minX + Int(Float(col) * cellWidth)
                let startY = minY + Int(Float(row) * cellHeight)
                let endX = min(minX + Int(Float(col + 1) * cellWidth), minX + regionWidth)
                let endY = min(minY + Int(Float(row + 1) * cellHeight), minY + regionHeight)

                var sum: Float = 0
                var count: Int = 0

                for y in startY..<endY {
                    let rowOffset = y * bytesPerRow
                    for x in startX..<endX {
                        let pixelOffset = rowOffset + (x * 4)
                        let blue = Float(bytes[pixelOffset])
                        let green = Float(bytes[pixelOffset + 1])
                        let red = Float(bytes[pixelOffset + 2])
                        sum += (0.0722 * blue) + (0.7152 * green) + (0.2126 * red)
                        count += 1
                    }
                }

                let average = count > 0 ? sum / Float(count) / 255.0 : 0.5
                result[row * gridSize + col] = average
            }
        }

        return result
    }
}
