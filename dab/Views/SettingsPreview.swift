import SwiftUI

/// The settings window's display module: a real LCD running the actual dab
/// pipeline over a bundled sample card, so every picture control shows its
/// effect in place. Sampling is `PreviewSampler` (static image, never a
/// capture stream), quantization is `GridFilters.apply`, drawing is the same
/// `GridCanvas` the overlay uses — the preview cannot lie.
struct SettingsPreview: View {
    let gridSize: Int
    let filterMode: FilterMode
    let brightnessThreshold: Float
    let palette: [PaletteSwatch]
    let horizontalMirrorMode: HorizontalMirrorMode
    let verticalMirrorMode: VerticalMirrorMode
    @Binding var renderMode: RenderMode
    var highlightedPaletteIndex: Int? = nil

    @State private var booted = false

    /// Loaded once; a missing asset shows "no signal".
    private static let sampler: PreviewSampler? = PreviewSampler(bundledImageNamed: "sample-shapes")

    private let lcdSide: CGFloat = 168
    private let hudHeight: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                lcdModule
                rightColumn
            }
            .padding(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(WatchTheme.caseInk, lineWidth: 1)
            )
            // Silkscreen tag riding the bezel seam: names the module without
            // spending a section title's height.
            .overlay(alignment: .topLeading) {
                Text("preview")
                    .font(WatchFont.body(9, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(WatchTheme.caseInk)
                    .padding(.horizontal, 4)
                    .background(WatchTheme.caseYellow)
                    .offset(x: 12, y: -6)
            }
        }
        .onAppear {
            guard !booted else { return }
            withAnimation(.easeOut(duration: 0.35)) { booted = true }
        }
    }

    // MARK: - LCD

    private var lcdModule: some View {
        VStack(spacing: 0) {
            ZStack {
                // Powered-off screen behind the booting content.
                WatchTheme.lcdGreen

                if booted {
                    screenContent
                        .transition(.lcdBoot)
                }
            }
            .frame(width: lcdSide, height: lcdSide)
            .clipped()

            hudBar
        }
        .overlay(Rectangle().stroke(WatchTheme.caseInk, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
    }

    @ViewBuilder
    private var screenContent: some View {
        // Settings changes snap instantly, like the overlay.
        if let grid = previewGridState {
            GridCanvas(gridState: grid, highlightedPaletteIndex: highlightedPaletteIndex)
        } else {
            noSignal
        }
    }

    private var noSignal: some View {
        ZStack {
            WatchTheme.lcdGreen
            Text("no signal")
                .font(WatchFont.body(11, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(WatchTheme.lcdInk)
        }
    }

    /// Replica of the overlay's info bar, minus session-only states
    /// (negative / randomizer aren't settings).
    private var hudBar: some View {
        HStack {
            Text(filterMode.shortDisplayName)
            if let label = horizontalMirrorMode.statusLabel {
                Text(label)
                    .foregroundColor(.orange)
            }
            if let label = verticalMirrorMode.statusLabel {
                Text(label)
                    .foregroundColor(.orange)
            }
            Spacer()
            Text(renderMode.displayName)
            Spacer()
            Text("\(gridSize)x\(gridSize)")
        }
        .font(.custom("Inconsolata", size: 11).weight(.semibold))
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 6)
        .frame(width: lcdSide, height: hudHeight)
        .background(Color.black)
    }

    // MARK: - Right column (render-mode keys + sample pusher)

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("render mode")
                .font(WatchFont.body(9, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(WatchTheme.caseInk.opacity(0.7))

            ForEach(RenderMode.allCases, id: \.self) { mode in
                modeKey(mode)
            }

            // Anchor a live readout to the bottom so the column carries content
            // top and bottom — the case-yellow between reads as deliberate watch
            // plastic, not a lopsided void.
            Spacer(minLength: 12)
            modeReadout
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: lcdSide + hudHeight)
    }

    private func modeKey(_ mode: RenderMode) -> some View {
        Button {
            renderMode = mode
        } label: {
            Text(mode.displayName.lowercased())
                .frame(maxWidth: .infinity)
                .frame(height: 26)
        }
        .buttonStyle(WatchKeyStyle(isSelected: renderMode == mode))
        .animation(.easeOut(duration: 0.15), value: renderMode)
    }

    /// Fills the space under the keys with a plain-language line on what the
    /// selected render mode does (invisible until now), plus the see-through
    /// note when a swatch is transparent.
    private var modeReadout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(WatchTheme.caseInk.opacity(0.22))
                .frame(height: 1)

            Text(renderModeBlurb(renderMode))
                .font(WatchFont.body(10, weight: .medium))
                .foregroundStyle(WatchTheme.caseInk.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            if let caption = seeThroughCaption {
                Text(caption)
                    .font(WatchFont.body(9, weight: .medium))
                    .foregroundStyle(WatchTheme.caseInk.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func renderModeBlurb(_ mode: RenderMode) -> String {
        switch mode {
        case .squares: return "solid tiles — the classic pixelation"
        case .dots:    return "round dots on a solid field"
        case .blobs:   return "cells merge into blobs · #1 paints the gaps"
        }
    }

    // MARK: - Pipeline

    private var previewGridState: GridState? {
        guard let sampler = Self.sampler else { return nil }

        let normalized = GridFilters.normalize(palette: palette)

        let colors: [PixelColor]
        let votes: [Int?]?
        if filterMode == .colorMatch {
            // Same vote path as CaptureViewModel.captureFrame, via the shared
            // helpers, so preview and overlay quantize identically.
            let (voteColors, voteToFullIndex) = GridFilters.votePalette(from: normalized)
            if voteColors.isEmpty {
                colors = sampler.averages(gridSize: gridSize)
                votes = nil
            } else {
                let bundle = sampler.averagesAndVotes(gridSize: gridSize, votePalette: voteColors)
                colors = bundle.colors
                votes = GridFilters.mapVotes(bundle.votes, toFullIndex: voteToFullIndex)
            }
        } else {
            colors = sampler.averages(gridSize: gridSize)
            votes = nil
        }

        var grid = GridState(size: gridSize, palette: normalized)
        grid.cells = GridFilters.apply(
            filterMode,
            colors: colors,
            gridSize: gridSize,
            palette: normalized,
            threshold: brightnessThreshold,
            paletteVotes: votes
        )
        grid.horizontalMirrorMode = horizontalMirrorMode
        grid.verticalMirrorMode = verticalMirrorMode
        grid.renderMode = renderMode
        return grid
    }

    private var seeThroughCaption: String? {
        let normalized = GridFilters.normalize(palette: palette)
        if normalized.allSatisfy(\.isTransparent) {
            return "all cells see-through — add a color swatch"
        }
        if normalized.contains(where: \.isTransparent) {
            return "checkerboard = see-through to your desktop"
        }
        return nil
    }
}

