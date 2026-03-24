import CoreGraphics
import CoreVideo

extension CVPixelBuffer {
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
