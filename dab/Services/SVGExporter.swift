import Foundation

enum SVGExporter {
    /// Generates an SVG string from the current grid state.
    static func generateSVG(from grid: GridState) -> String {
        let n = grid.size
        switch grid.renderMode {
        case .squares:
            return squareSVG(grid: grid, n: n)
        case .dots:
            return dotsSVG(grid: grid, n: n)
        case .blobs:
            return blobsSVG(grid: grid, n: n)
        }
    }

    private static func cellRects(for grid: GridState, n: Int) -> [String] {
        var rects: [String] = []
        for row in 0..<n {
            for col in 0..<n {
                guard let swatch = grid.effectiveSwatch(row: row, col: col) else { continue }
                rects.append("  <rect x=\"\(col)\" y=\"\(row)\" width=\"1\" height=\"1\" fill=\"\(swatch.color.hexString)\"/>")
            }
        }
        return rects
    }

    private static func emptySVG(n: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(n) \(n)" width="\(n * 10)" height="\(n * 10)"></svg>
        """
    }

    private static func squareSVG(grid: GridState, n: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(n) \(n)" width="\(n * 10)" height="\(n * 10)" shape-rendering="crispEdges">
        \(cellRects(for: grid, n: n).joined(separator: "\n"))
        </svg>
        """
    }

    /// Dots: rounded blobs over a single dominant-color background grout.
    private static func dotsSVG(grid: GridState, n: Int) -> String {
        let indices = grid.usedEffectivePaletteIndices()
        let squareClip = RoundedGridPath.svgSquarePathData(for: grid, matchingPaletteIndex: nil)
        guard !indices.isEmpty, !squareClip.isEmpty else { return emptySVG(n: n) }

        var grout: [String] = []
        if let dom = grid.dominantPaletteIndex(), dom < grid.palette.count {
            // Fill the whole silhouette with the dominant color (clipped to it).
            grout.append("  <path d=\"\(squareClip)\" fill=\"\(grid.palette[dom].color.hexString)\" fill-rule=\"evenodd\"/>")
        }
        return wrapRounded(n: n, clip: squareClip, parts: grout + blobParts(for: grid, indices: indices))
    }

    /// Blobs: rounded blobs over a palette-order grout (lowest index wins gaps).
    private static func blobsSVG(grid: GridState, n: Int) -> String {
        let indices = grid.usedEffectivePaletteIndices()
        let squareClip = RoundedGridPath.svgSquarePathData(for: grid, matchingPaletteIndex: nil)
        guard !indices.isEmpty, !squareClip.isEmpty else { return emptySVG(n: n) }

        var grout: [String] = []
        // Dilated square regions (stroke-width 1 = half-cell dilation), highest
        // palette index first so the lowest index wins the contested gaps.
        for index in indices.reversed() where index < grid.palette.count {
            let fill = grid.palette[index].color.hexString
            let square = RoundedGridPath.svgSquarePathData(for: grid, matchingPaletteIndex: index)
            if !square.isEmpty {
                grout.append("  <path d=\"\(square)\" fill=\"\(fill)\" stroke=\"\(fill)\" stroke-width=\"1\" stroke-linejoin=\"round\" fill-rule=\"evenodd\"/>")
            }
        }
        return wrapRounded(n: n, clip: squareClip, parts: grout + blobParts(for: grid, indices: indices))
    }

    /// Per-color rounded blobs + diagonal bridges, lowest to highest. Shared by
    /// Dots and Blobs (they differ only in their grout).
    private static func blobParts(for grid: GridState, indices: [Int]) -> [String] {
        var parts: [String] = []
        for index in indices where index < grid.palette.count {
            let fill = grid.palette[index].color.hexString
            let blob = RoundedGridPath.svgBoundaryPathData(for: grid, matchingPaletteIndex: index)
            if !blob.isEmpty {
                parts.append("  <path d=\"\(blob)\" fill=\"\(fill)\" fill-rule=\"evenodd\"/>")
            }
            let bridge = RoundedGridPath.svgBridgePathData(for: grid, matchingPaletteIndex: index)
            if !bridge.isEmpty {
                parts.append("  <path d=\"\(bridge)\" fill=\"\(fill)\"/>")
            }
        }
        return parts
    }

    /// Wraps grout + blob paths in a clip to the square outer silhouette.
    private static func wrapRounded(n: Int, clip: String, parts: [String]) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(n) \(n)" width="\(n * 10)" height="\(n * 10)">
        <defs>
        <clipPath id="rounded"><path d="\(clip)" clip-rule="evenodd"/></clipPath>
        </defs>
        <g clip-path="url(#rounded)">
        \(parts.joined(separator: "\n"))
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
