import AppKit
import CoreGraphics
import ImageIO

/// Samples a bundled still image the way the live pipeline samples the screen:
/// per-cell average colors, plus per-source-pixel palette votes for Color
/// Match. The loops mirror `CVPixelBuffer.colorAndVoteGrid` — same redmean
/// argmin per pixel, same majority + summed-distance + lowest-index
/// tie-breaks — just over a decoded RGBA buffer instead of a capture frame.
///
/// Pure and synchronous. The settings preview must never open a capture
/// stream (see docs/postmortem-2026-03-29-preview-render-instability.md);
/// this class is the whole "capture" side of the preview.
final class PreviewSampler {
    /// Decode/sample resolution. Sample cards ship at 128×128; anything else
    /// is scaled to this on load.
    private static let side = 128

    private struct VoteKey: Hashable {
        let gridSize: Int
        let palette: [PixelColor]
    }

    private let width: Int
    private let height: Int
    private let pixels: [UInt8] // RGBA8, tightly packed
    private var averageCache: [Int: [PixelColor]] = [:]
    private var voteCache: [VoteKey: (colors: [PixelColor], votes: [Int?])] = [:]

    init?(cgImage: CGImage) {
        let side = Self.side
        width = side
        height = side

        var buffer = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let ctx = CGContext(
                      data: raw.baseAddress,
                      width: side,
                      height: side,
                      bitsPerComponent: 8,
                      bytesPerRow: side * 4,
                      space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }
            ctx.interpolationQuality = .high
            // Aspect-fill center crop so any replacement image samples
            // undistorted regardless of its dimensions.
            let iw = CGFloat(max(cgImage.width, 1))
            let ih = CGFloat(max(cgImage.height, 1))
            let scale = max(CGFloat(side) / iw, CGFloat(side) / ih)
            let drawSize = CGSize(width: iw * scale, height: ih * scale)
            let origin = CGPoint(
                x: (CGFloat(side) - drawSize.width) / 2,
                y: (CGFloat(side) - drawSize.height) / 2
            )
            ctx.draw(cgImage, in: CGRect(origin: origin, size: drawSize))
            return true
        }

        guard drawn else { return nil }
        pixels = buffer
    }

    convenience init?(bundledImageNamed name: String, extension ext: String = "png") {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        self.init(cgImage: image)
    }

    /// NxN grid of average colors (cached per grid size — the image is fixed).
    func averages(gridSize: Int) -> [PixelColor] {
        if let cached = averageCache[gridSize] {
            return cached
        }
        let (colors, _) = compute(gridSize: gridSize, votePalette: [])
        averageCache[gridSize] = colors
        return colors
    }

    /// NxN grid of (average color, vote winner). Votes are indices into
    /// `votePalette`; map them with `GridFilters.mapVotes` before `apply`.
    /// Memoized: the preview's body re-evaluates on every unrelated settings
    /// change, and this pass shouldn't re-run unless its inputs did.
    func averagesAndVotes(gridSize: Int, votePalette: [PixelColor]) -> (colors: [PixelColor], votes: [Int?]) {
        let key = VoteKey(gridSize: gridSize, palette: votePalette)
        if let cached = voteCache[key] {
            return cached
        }

        let result = compute(gridSize: gridSize, votePalette: votePalette)
        averageCache[gridSize] = result.colors
        // Color-well drags mint a new palette per tick; keep the cache bounded.
        if voteCache.count > 32 {
            voteCache.removeAll()
        }
        voteCache[key] = result
        return result
    }

    // MARK: - Core (mirrors CVPixelBuffer.colorAndVoteGrid)

    private func compute(gridSize: Int, votePalette: [PixelColor]) -> (colors: [PixelColor], votes: [Int?]) {
        guard gridSize > 0 else { return ([], []) }

        let cellCount = gridSize * gridSize
        let fallbackColor = PixelColor(red: 0.5, green: 0.5, blue: 0.5)

        let cellWidth = Float(width) / Float(gridSize)
        let cellHeight = Float(height) / Float(gridSize)

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

        var voteCounts = [Int](repeating: 0, count: max(paletteCount, 1))
        var voteDistances = [Float](repeating: 0, count: max(paletteCount, 1))

        pixels.withUnsafeBufferPointer { bytes in
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    let startX = Int(Float(col) * cellWidth)
                    let startY = Int(Float(row) * cellHeight)
                    let endX = min(Int(Float(col + 1) * cellWidth), width)
                    let endY = min(Int(Float(row + 1) * cellHeight), height)

                    var redSum: Float = 0
                    var greenSum: Float = 0
                    var blueSum: Float = 0
                    var count = 0

                    if paletteCount > 0 {
                        for i in 0..<paletteCount {
                            voteCounts[i] = 0
                            voteDistances[i] = 0
                        }
                    }

                    for y in startY..<endY {
                        let rowOffset = y * width * 4
                        for x in startX..<endX {
                            let pixelOffset = rowOffset + (x * 4)
                            let r = Float(bytes[pixelOffset])
                            let g = Float(bytes[pixelOffset + 1])
                            let b = Float(bytes[pixelOffset + 2])
                            redSum += r
                            greenSum += g
                            blueSum += b
                            count += 1

                            guard paletteCount > 0 else { continue }

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
                                } else if c == winnerCount, voteDistances[i] < winnerDistance {
                                    winnerIndex = i
                                    winnerDistance = voteDistances[i]
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
        }

        return (colors, votes)
    }
}
