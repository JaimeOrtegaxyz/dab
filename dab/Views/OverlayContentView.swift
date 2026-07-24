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
    let isRandomizing: Bool
    let randomVariationIndex: Int
    /// Set for a beat after `c` switches palettes, then cleared — see
    /// `CaptureViewModel.flashPaletteName`.
    let paletteFlash: String?

    var body: some View {
        VStack(spacing: 0) {
            GridCanvas(gridState: gridState)
                .frame(width: viewportSize, height: viewportSize)
                .border(Color.gray.opacity(0.5), width: 1)

            // Info bar
            HStack {
                Text(filterMode.shortDisplayName)
                if let paletteFlash {
                    Text(paletteFlash)
                        .foregroundColor(.green)
                }
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
            // Fades the palette name in and back out rather than popping it.
            .animation(.easeOut(duration: 0.2), value: paletteFlash)
        }
    }
}
