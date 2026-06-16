import SwiftUI

private extension Color {
    init(pixelColor: PixelColor) {
        self.init(
            red: Double(pixelColor.red),
            green: Double(pixelColor.green),
            blue: Double(pixelColor.blue)
        )
    }
}

struct OverlayContentView: View {
    static let infoBarHeight: CGFloat = 20

    let gridState: GridState
    let gridSize: Int
    let viewportSize: CGFloat
    let filterMode: FilterMode
    let isInverted: Bool
    let horizontalMirrorMode: HorizontalMirrorMode
    let verticalMirrorMode: VerticalMirrorMode
    let isRandomizing: Bool
    let randomVariationIndex: Int

    var body: some View {
        VStack(spacing: 0) {
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
            }
            .frame(width: viewportSize, height: viewportSize)
            .border(Color.gray.opacity(0.5), width: 1)

            // Info bar
            HStack {
                Text(filterMode.shortDisplayName)
                if isRandomizing {
                    Text("random \(randomVariationIndex)")
                        .foregroundColor(.cyan)
                }
                if isInverted {
                    Text("Negative")
                        .foregroundColor(.yellow)
                }
                if let label = horizontalMirrorMode.statusLabel {
                    Text(label)
                        .foregroundColor(.orange)
                }
                if let label = verticalMirrorMode.statusLabel {
                    Text(label)
                        .foregroundColor(.orange)
                }
                Spacer()
                Text(gridState.renderMode.displayName)
                Spacer()
                Text("\(gridSize)x\(gridSize)")
            }
            .font(.custom("Inconsolata", size: 11).weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .frame(width: viewportSize, height: Self.infoBarHeight)
            .background(Color.black)
        }
    }

    /// Square pixels — one fill per colored cell. Shared by Square mode and (via
    /// a clipped context) Mix mode.
    private func drawCells(in context: GraphicsContext, size: CGSize) {
        let actualSize = gridState.size
        guard actualSize > 0 else { return }
        let cellW = size.width / CGFloat(actualSize)
        let cellH = size.height / CGFloat(actualSize)

        for row in 0..<actualSize {
            for col in 0..<actualSize {
                guard let swatch = gridState.effectiveSwatch(row: row, col: col) else { continue }
                let rect = CGRect(x: CGFloat(col) * cellW, y: CGFloat(row) * cellH, width: cellW, height: cellH)
                context.fill(Path(rect), with: .color(Color(pixelColor: swatch.color)))
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
}
