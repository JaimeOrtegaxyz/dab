import SwiftUI

struct OverlayContentView: View {
    static let infoBarHeight: CGFloat = 20

    let gridState: GridState
    let gridSize: Int
    let viewportSize: CGFloat
    let filterMode: FilterMode
    let isInverted: Bool
    let horizontalMirrorMode: HorizontalMirrorMode
    let verticalMirrorMode: VerticalMirrorMode

    var body: some View {
        VStack(spacing: 0) {
            Canvas { context, size in
                let actualSize = gridState.size
                guard actualSize > 0 else { return }

                // Fill white background
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.white)
                )

                if gridState.isRounded {
                    let roundedPath = RoundedGridPath.cgPath(
                        for: gridState,
                        in: CGRect(origin: .zero, size: size)
                    )
                    context.fill(Path(roundedPath), with: .color(.black))
                } else {
                    let cellW = size.width / CGFloat(actualSize)
                    let cellH = size.height / CGFloat(actualSize)

                    for row in 0..<actualSize {
                        for col in 0..<actualSize {
                            if gridState.effectiveCell(row: row, col: col) {
                                let rect = CGRect(
                                    x: CGFloat(col) * cellW,
                                    y: CGFloat(row) * cellH,
                                    width: cellW,
                                    height: cellH
                                )
                                context.fill(Path(rect), with: .color(.black))
                            }
                        }
                    }
                }
            }
            .frame(width: viewportSize, height: viewportSize)
            .border(Color.gray.opacity(0.5), width: 1)

            // Info bar
            HStack {
                Text(filterMode.shortDisplayName)
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
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .frame(width: viewportSize, height: Self.infoBarHeight)
            .background(Color.black)
        }
    }
}
