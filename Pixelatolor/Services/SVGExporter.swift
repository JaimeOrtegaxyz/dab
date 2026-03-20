import Foundation

enum SVGExporter {
    /// Generates an SVG string from a GridState with one exact 1x1 square per black cell.
    /// White cells remain transparent.
    static func generateSVG(from grid: GridState) -> String {
        let n = grid.size
        var rects: [String] = []

        for row in 0..<n {
            for col in 0..<n {
                if grid.effectiveCell(row: row, col: col) {
                    rects.append("    <rect x=\"\(col)\" y=\"\(row)\" width=\"1\" height=\"1\"/>")
                }
            }
        }

        if rects.isEmpty {
            return """
            <?xml version="1.0" encoding="UTF-8"?>
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(n) \(n)" width="\(n * 10)" height="\(n * 10)" shape-rendering="crispEdges">
            </svg>
            """
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(n) \(n)" width="\(n * 10)" height="\(n * 10)" shape-rendering="crispEdges">
          <g fill="black">
        \(rects.joined(separator: "\n"))
          </g>
        </svg>
        """
    }

    /// Builds a filename from the user's format string.
    /// Supported tokens: {date}, {time}, {grid}, {timestamp}
    static func buildFilename(from format: String, gridSize: Int) -> String {
        let now = Date()
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HHmmss"

        var name = format
        name = name.replacingOccurrences(of: "{date}", with: dateFmt.string(from: now))
        name = name.replacingOccurrences(of: "{time}", with: timeFmt.string(from: now))
        name = name.replacingOccurrences(of: "{grid}", with: "\(gridSize)x\(gridSize)")
        name = name.replacingOccurrences(of: "{timestamp}", with: "\(Int(now.timeIntervalSince1970))")

        // Sanitize for filesystem
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        name = name.components(separatedBy: illegal).joined(separator: "_")

        if name.isEmpty { name = "pixelatolor" }
        return name + ".svg"
    }

    /// Saves the SVG to a file and returns the URL
    @discardableResult
    static func save(grid: GridState, to directory: URL, filenameFormat: String = "pixelatolor_{date}_{time}") -> URL? {
        let filename = buildFilename(from: filenameFormat, gridSize: grid.size)
        let url = directory.appendingPathComponent(filename)

        let svg = generateSVG(from: grid)

        do {
            _ = directory.startAccessingSecurityScopedResource()
            defer { directory.stopAccessingSecurityScopedResource() }
            try svg.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            do {
                try svg.write(to: url, atomically: true, encoding: .utf8)
                return url
            } catch {
                print("Failed to save SVG: \(error)")
                return nil
            }
        }
    }
}
