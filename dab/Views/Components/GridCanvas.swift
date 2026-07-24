import SwiftUI

/// The dab picture renderer: draws a `GridState` into a SwiftUI `Canvas` at
/// whatever size it's framed to. Shared by the live overlay and the settings
/// preview so both always run the exact same drawing pipeline.
///
/// Drawing code moved verbatim from `OverlayContentView`.
struct GridCanvas: View {
    let gridState: GridState

    /// When set, every cell whose effective palette index differs is washed
    /// out — the settings preview uses this to show which cells a hovered
    /// swatch owns. The wash is a grid-aligned overlay pass, so it reads the
    /// same in squares, dots, and blobs modes.
    var highlightedPaletteIndex: Int? = nil

    /// Device pixels per point, used to snap cell edges onto the physical pixel
    /// grid (see `snappedEdges`).
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Canvas { context, size in
            let actualSize = gridState.size
            guard actualSize > 0 else { return }

            drawTransparencyBackground(in: context, size: size)

            let rect = CGRect(origin: .zero, size: size)
            switch gridState.renderMode {
            case .squares:
                drawCells(in: context, size: size)
            case .dots:
                drawGroutAndBlobs(in: context, rect: rect, size: size, grout: .dominant)
            case .blobs:
                drawGroutAndBlobs(in: context, rect: rect, size: size, grout: .paletteOrder)
            }

            if let highlighted = highlightedPaletteIndex {
                drawHighlightWash(in: context, size: size, keeping: highlighted)
            }
        }
    }

    /// Cell-boundary positions along `length`, one per grid line (count + 1 of
    /// them), each snapped to the nearest whole device pixel.
    ///
    /// This is what kills the white seams between squares. `Canvas` anti-aliases
    /// every fill, so when two differently-colored cells meet on a *fractional*
    /// pixel edge, each only partially covers the boundary pixels and the white
    /// background painted underneath leaks through as a hairline — worse at high
    /// grid sizes where the fractional part lands differently on every edge.
    /// Snapping every boundary onto the physical pixel grid makes adjacent cells
    /// share an exact integer edge, so there's no partial coverage and no gap.
    private func snappedEdges(count: Int, length: CGFloat) -> [CGFloat] {
        let scale = max(displayScale, 1)
        return (0...count).map { i in
            ((CGFloat(i) * length / CGFloat(count)) * scale).rounded() / scale
        }
    }

    /// Square pixels, drawn with antialiasing disabled.
    ///
    /// Every edge in this mode is axis-aligned, so AA can only hurt: wherever a
    /// cell boundary misses the physical pixel grid — fractional view origin, a
    /// scaled canvas, anything outside local coordinates — the boundary pixel's
    /// coverage is split between the two fills and the white background
    /// composites through as flickering hairlines. Snapping edges in *local*
    /// space (`snappedEdges`, still used so cells stay uniform and the hover
    /// wash aligns) can't reach misalignment introduced by the layout chain.
    /// With AA off each raster pixel belongs wholly to exactly one fill, so
    /// neighbors tile with zero gaps by construction, at any alignment. The
    /// dots/blobs paths keep AA — their curves need it, and their dilated
    /// geometry never leaked.
    private func drawCells(in context: GraphicsContext, size: CGSize) {
        let actualSize = gridState.size
        guard actualSize > 0 else { return }
        let xEdges = snappedEdges(count: actualSize, length: size.width)
        let yEdges = snappedEdges(count: actualSize, length: size.height)

        var rectsByColor: [PixelColor: [CGRect]] = [:]
        for row in 0..<actualSize {
            for col in 0..<actualSize {
                guard let swatch = gridState.effectiveSwatch(row: row, col: col) else { continue }
                rectsByColor[swatch.color, default: []].append(CGRect(
                    x: xEdges[col],
                    y: yEdges[row],
                    width: xEdges[col + 1] - xEdges[col],
                    height: yEdges[row + 1] - yEdges[row]
                ))
            }
        }

        context.withCGContext { cg in
            cg.setShouldAntialias(false)
            for (color, rects) in rectsByColor {
                cg.setFillColor(CGColor(
                    srgbRed: CGFloat(color.red),
                    green: CGFloat(color.green),
                    blue: CGFloat(color.blue),
                    alpha: 1
                ))
                cg.fill(rects)
            }
        }
    }

    private enum Grout {
        /// Dots: one solid background = the dominant (most-used) color.
        case dominant
        /// Blobs: per-region grout, palette order (lowest index wins gaps).
        case paletteOrder
    }

    /// Dots/Blobs: a grout fills the gaps while the composition's outer edge
    /// stays square, with per-color rounded blobs drawn on top. Clipped to the
    /// square silhouette so transparent cells keep showing the background.
    private func drawGroutAndBlobs(in context: GraphicsContext, rect: CGRect, size: CGSize, grout: Grout) {
        let indices = gridState.usedEffectivePaletteIndices()
        guard !indices.isEmpty, gridState.size > 0 else { return }

        let silhouette = Path(RoundedGridPath.squareCGPath(for: gridState, in: rect, matchingPaletteIndex: nil))
        let cellSize = min(size.width, size.height) / CGFloat(gridState.size)

        var ctx = context
        ctx.clip(to: silhouette)

        switch grout {
        case .dominant:
            if let dom = gridState.dominantPaletteIndex(), dom < gridState.palette.count {
                ctx.fill(silhouette, with: .color(Color(pixelColor: gridState.palette[dom].color)))
            }
        case .paletteOrder:
            // Each region's square dilated by half a cell (fill + round-joined
            // stroke), painted highest palette index first so the lowest index
            // lands on top and wins the contested gaps between blobs.
            for index in indices.reversed() where index < gridState.palette.count {
                let color = Color(pixelColor: gridState.palette[index].color)
                let square = Path(RoundedGridPath.squareCGPath(for: gridState, in: rect, matchingPaletteIndex: index))
                ctx.fill(square, with: .color(color))
                ctx.stroke(square, with: .color(color), style: StrokeStyle(lineWidth: cellSize, lineJoin: .round))
            }
        }

        // Blobs: per-color rounded boundary + diagonal bridges, lowest to highest.
        for index in indices where index < gridState.palette.count {
            let color = Color(pixelColor: gridState.palette[index].color)
            ctx.fill(Path(RoundedGridPath.cgPath(for: gridState, in: rect, matchingPaletteIndex: index)), with: .color(color))
            ctx.fill(Path(RoundedGridPath.bridgeCGPath(for: gridState, in: rect, matchingPaletteIndex: index)), with: .color(color))
        }
    }

    private func drawTransparencyBackground(in context: GraphicsContext, size: CGSize) {
        let baseRect = CGRect(origin: .zero, size: size)
        context.fill(Path(baseRect), with: .color(.white))

        let checkerSize: CGFloat = 8
        let columns = Int(ceil(size.width / checkerSize))
        let rows = Int(ceil(size.height / checkerSize))

        for row in 0..<rows {
            for col in 0..<columns where (row + col).isMultiple(of: 2) {
                let rect = CGRect(
                    x: CGFloat(col) * checkerSize,
                    y: CGFloat(row) * checkerSize,
                    width: checkerSize,
                    height: checkerSize
                )
                context.fill(Path(rect), with: .color(Color.gray.opacity(0.14)))
            }
        }
    }

    /// White wash over every cell the highlighted swatch does NOT own, leaving
    /// its own cells at full strength. A see-through swatch's cells resolve to
    /// nil in `effectivePaletteIndex`, so ownership for those is decided on the
    /// raw cell assignment instead.
    private func drawHighlightWash(in context: GraphicsContext, size: CGSize, keeping index: Int) {
        let actualSize = gridState.size
        guard actualSize > 0 else { return }
        let xEdges = snappedEdges(count: actualSize, length: size.width)
        let yEdges = snappedEdges(count: actualSize, length: size.height)

        let paletteCount = gridState.palette.count
        let keepingSeeThrough = index >= 0 && index < paletteCount && gridState.palette[index].isTransparent

        // Merge the washed cells into one path so the translucent fill lands as
        // a single coverage pass — overlapping per-cell fills would double up on
        // shared edges and read as seams of their own.
        var wash = Path()
        for row in 0..<actualSize {
            for col in 0..<actualSize {
                let owned: Bool
                if keepingSeeThrough {
                    if case .palette(let raw) = gridState.effectiveCell(row: row, col: col) {
                        owned = min(max(raw, 0), paletteCount - 1) == index
                    } else {
                        owned = false
                    }
                } else {
                    owned = gridState.effectivePaletteIndex(row: row, col: col) == index
                }
                guard !owned else { continue }
                wash.addRect(CGRect(
                    x: xEdges[col],
                    y: yEdges[row],
                    width: xEdges[col + 1] - xEdges[col],
                    height: yEdges[row + 1] - yEdges[row]
                ))
            }
        }
        context.fill(wash, with: .color(.white.opacity(0.6)))
    }
}
