import Foundation

enum SVGExporter {
    /// Generates an SVG string from the current grid state.
    static func generateSVG(from grid: GridState) -> String {
        let n = grid.size

        if grid.isRounded {
            var pathElements: [String] = []

            for paletteIndex in grid.usedEffectivePaletteIndices() {
                guard paletteIndex < grid.palette.count else { continue }
                let fill = grid.palette[paletteIndex].color.hexString
                let boundaryPathData = RoundedGridPath.svgBoundaryPathData(
                    for: grid,
                    matchingPaletteIndex: paletteIndex
                )
                let bridgePathData = RoundedGridPath.svgBridgePathData(
                    for: grid,
                    matchingPaletteIndex: paletteIndex
                )

                if !boundaryPathData.isEmpty {
                    pathElements.append("<path d=\"\(boundaryPathData)\" fill=\"\(fill)\" fill-rule=\"evenodd\"/>")
                }
                if !bridgePathData.isEmpty {
                    pathElements.append("<path d=\"\(bridgePathData)\" fill=\"\(fill)\"/>")
                }
            }

            return """
            <?xml version="1.0" encoding="UTF-8"?>
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(n) \(n)" width="\(n * 10)" height="\(n * 10)">
            \(pathElements.joined(separator: "\n"))
            </svg>
            """
        }

        var rects: [String] = []

        for row in 0..<n {
            for col in 0..<n {
                guard let swatch = grid.effectiveSwatch(row: row, col: col) else {
                    continue
                }

                rects.append("  <rect x=\"\(col)\" y=\"\(row)\" width=\"1\" height=\"1\" fill=\"\(swatch.color.hexString)\"/>")
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(n) \(n)" width="\(n * 10)" height="\(n * 10)" shape-rendering="crispEdges">
        \(rects.joined(separator: "\n"))
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

        if name.isEmpty { name = "dab" }
        return name + ".svg"
    }

    /// Saves the SVG to a file and returns the URL
    @discardableResult
    static func save(grid: GridState, to directory: URL, filenameFormat: String = "dab_{date}_{time}") -> URL? {
        let filename = buildFilename(from: filenameFormat, gridSize: grid.size)
        let svg = generateSVG(from: grid)

        let didAccess = directory.startAccessingSecurityScopedResource()
        defer { if didAccess { directory.stopAccessingSecurityScopedResource() } }

        // Avoid silently overwriting an earlier export written within the same
        // second (the default filename template is second-resolution): append a
        // numeric suffix until we find a free path.
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var url = directory.appendingPathComponent(filename)
        var counter = 1
        while FileManager.default.fileExists(atPath: url.path) {
            let candidate = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            url = directory.appendingPathComponent(candidate)
            counter += 1
        }

        do {
            try svg.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            // The retry that used to live here re-ran the identical write with
            // the security scope already released, so it could never recover and
            // only obscured the real error. Surface the original failure instead.
            print("Failed to save SVG: \(error)")
            return nil
        }
    }
}
