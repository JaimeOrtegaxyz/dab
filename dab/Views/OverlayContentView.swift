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

                if gridState.isRounded {
                    for paletteIndex in gridState.usedEffectivePaletteIndices() {
                        guard paletteIndex < gridState.palette.count else { continue }
                        let roundedPath = RoundedGridPath.cgPath(
                            for: gridState,
                            in: CGRect(origin: .zero, size: size),
                            matchingPaletteIndex: paletteIndex
                        )
                        context.fill(
                            Path(roundedPath),
                            with: .color(Color(pixelColor: gridState.palette[paletteIndex].color))
                        )
                    }
                } else {
                    let cellW = size.width / CGFloat(actualSize)
                    let cellH = size.height / CGFloat(actualSize)

                    for row in 0..<actualSize {
                        for col in 0..<actualSize {
                            guard let swatch = gridState.effectiveSwatch(row: row, col: col) else {
                                continue
                            }

                            let rect = CGRect(
                                x: CGFloat(col) * cellW,
                                y: CGFloat(row) * cellH,
                                width: cellW,
                                height: cellH
                            )
                            context.fill(Path(rect), with: .color(Color(pixelColor: swatch.color)))
                        }
                    }
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
                Text(gridState.isRounded ? "Round" : "Square")
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
