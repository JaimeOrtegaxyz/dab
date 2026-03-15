import CoreGraphics

extension CGImage {
    /// Computes an NxN grid of average brightness values from the image.
    /// Returns a flat array of size gridSize*gridSize with values 0.0 (black) to 1.0 (white).
    func brightnessGrid(gridSize: Int) -> [Float] {
        let w = width
        let h = height

        guard w > 0, h > 0, gridSize > 0 else {
            return Array(repeating: 0.5, count: gridSize * gridSize)
        }

        // Render into a grayscale bitmap for fast access
        let bitmapW = w
        let bitmapH = h
        let bytesPerRow = bitmapW
        var pixelData = [UInt8](repeating: 0, count: bitmapW * bitmapH)

        guard let context = CGContext(
            data: &pixelData,
            width: bitmapW,
            height: bitmapH,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return Array(repeating: 0.5, count: gridSize * gridSize)
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: bitmapW, height: bitmapH))

        var result = [Float](repeating: 0, count: gridSize * gridSize)
        let cellW = Float(bitmapW) / Float(gridSize)
        let cellH = Float(bitmapH) / Float(gridSize)

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x0 = Int(Float(col) * cellW)
                let y0 = Int(Float(row) * cellH)
                let x1 = min(Int(Float(col + 1) * cellW), bitmapW)
                let y1 = min(Int(Float(row + 1) * cellH), bitmapH)

                var sum: Int = 0
                var count: Int = 0
                for y in y0..<y1 {
                    for x in x0..<x1 {
                        sum += Int(pixelData[y * bytesPerRow + x])
                        count += 1
                    }
                }

                let avg = count > 0 ? Float(sum) / Float(count) / 255.0 : 0.5
                result[row * gridSize + col] = avg
            }
        }

        return result
    }
}
