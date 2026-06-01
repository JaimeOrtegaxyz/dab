import AppKit
import Combine
import os

final class CaptureViewModel: ObservableObject {
    /// Immutable value-type copy of every piece of state the capture loop
    /// reads. Built on the main thread on each mutation and published through
    /// `stateLock`, so `captureFrame()` (running on `captureQueue`) never
    /// touches the `@Published` properties directly — eliminating the data
    /// race on `palette`'s copy-on-write storage and the scalar fields.
    private struct CaptureSnapshot {
        var gridSize: Int = 16
        var viewportSize: CGFloat = 200
        var brightnessThreshold: Float = 0.5
        var filterMode: FilterMode = .colorMatch
        var palette: [PaletteSwatch] = PaletteSwatch.defaultPalette
        var isInverted: Bool = false
        var horizontalMirrorMode: HorizontalMirrorMode = .none
        var verticalMirrorMode: VerticalMirrorMode = .none
        var isRounded: Bool = false
        var isRandomizing: Bool = false
        var randomVariationIndex: Int = 0
    }

    private let stateLock = OSAllocatedUnfairLock(initialState: CaptureSnapshot())

    @Published var gridState = GridState(size: 16)
    @Published var gridSize: Int = 16
    @Published var viewportSize: CGFloat = 200
    @Published var brightnessThreshold: Float = 0.5
    @Published var filterMode: FilterMode = .colorMatch
    @Published var palette: [PaletteSwatch] = PaletteSwatch.defaultPalette
    @Published var isInverted: Bool = false
    @Published var horizontalMirrorMode: HorizontalMirrorMode = .none
    @Published var verticalMirrorMode: VerticalMirrorMode = .none
    @Published var isRounded: Bool = false
    @Published var isActive: Bool = false
    @Published var lastSavedURL: URL?
    @Published var isRandomizing: Bool = false
    @Published var randomVariationIndex: Int = 0

    private let captureService = ScreenCaptureService()
    private var timer: DispatchSourceTimer?
    private let captureQueue = DispatchQueue(label: "com.dab.capture", qos: .userInteractive)
    private let streamKeepAliveDuration: TimeInterval = 12

    func loadSettings() {
        let settings = AppSettings.shared
        gridSize = settings.gridSize
        viewportSize = settings.viewportSize
        brightnessThreshold = settings.brightnessThreshold
        filterMode = settings.filterMode
        palette = settings.palette
        horizontalMirrorMode = settings.horizontalMirrorMode
        verticalMirrorMode = settings.verticalMirrorMode
        randomVariationIndex = settings.lastRandomVariationIndex
        publishSnapshot()
    }

    func activate() {
        loadSettings()
        isInverted = false
        isRounded = false
        // The randomizer is a deliberate, modal action — never auto-enter
        // it on capture start, even if the last session ended inside it.
        isRandomizing = false
        syncCurrentGridPresentation()
        publishSnapshot()
        isActive = true
    }

    /// Copy the current `@Published` state into the lock-protected snapshot.
    /// Must be called on the main thread after any mutation of the fields the
    /// capture loop consumes.
    private func publishSnapshot() {
        let snapshot = CaptureSnapshot(
            gridSize: gridSize,
            viewportSize: viewportSize,
            brightnessThreshold: brightnessThreshold,
            filterMode: filterMode,
            palette: palette,
            isInverted: isInverted,
            horizontalMirrorMode: horizontalMirrorMode,
            verticalMirrorMode: verticalMirrorMode,
            isRounded: isRounded,
            isRandomizing: isRandomizing,
            randomVariationIndex: randomVariationIndex
        )
        stateLock.withLock { $0 = snapshot }
    }

    func startCapturing() {
        captureQueue.async { [captureService] in
            // Force a fresh stream so filter exclusions are rebuilt for the live overlay.
            captureService.stop()
            captureService.prepare(at: ScreenCaptureService.currentMouseLocation())
        }
        startCaptureLoop()
    }

    func prewarmCaptureResources() {
        captureQueue.async { [captureService] in
            captureService.prewarm()
        }
    }

    func deactivate() {
        isActive = false
        stopCaptureLoop()
        captureService.stop(keepAliveFor: streamKeepAliveDuration)
    }

    @discardableResult
    func handleKeyDown(_ event: NSEvent) -> Bool {
        if event.isARepeat && !allowsKeyRepeat(for: event.keyCode) {
            return true
        }

        let isCoarseAdjustment = event.modifierFlags.contains(.shift)
        let viewportStep = AppSettings.shared.resizeStep * (isCoarseAdjustment ? 4 : 1)
        let gridStep = isCoarseAdjustment ? 4 : 1
        let thresholdStep: Float = 0.05 * (isCoarseAdjustment ? 4 : 1)

        switch event.keyCode {
        case 123:
            viewportSize = max(60, viewportSize - viewportStep)
        case 124:
            viewportSize = min(600, viewportSize + viewportStep)
        case 126:
            gridSize = min(32, gridSize + gridStep)
        case 125:
            gridSize = max(4, gridSize - gridStep)
        case 24, 69:
            brightnessThreshold = min(1.0, brightnessThreshold + thresholdStep)
        case 27, 78:
            brightnessThreshold = max(0.0, brightnessThreshold - thresholdStep)
        case 49:
            isInverted.toggle()
            syncCurrentGridPresentation()
        case 4:
            horizontalMirrorMode = horizontalMirrorMode.next
            syncCurrentGridPresentation()
        case 9:
            verticalMirrorMode = verticalMirrorMode.next
            syncCurrentGridPresentation()
        case 15:
            isRounded.toggle()
            syncCurrentGridPresentation()
        case 18:
            filterMode = .colorMatch
        case 19:
            filterMode = .threshold
        case 20:
            filterMode = .halftone
        case 26:
            filterMode = .edgeDetect
        case 6:
            // Z — toggle the palette randomizer. Entering re-applies the
            // last-used variation index; exiting reverts to the user's
            // real palette but keeps the index for next time.
            isRandomizing.toggle()
        case 30:
            // ] — next variation (only meaningful while randomizing).
            guard isRandomizing else { return false }
            randomVariationIndex &+= 1
            AppSettings.shared.lastRandomVariationIndex = randomVariationIndex
        case 33:
            // [ — previous variation.
            guard isRandomizing else { return false }
            randomVariationIndex &-= 1
            AppSettings.shared.lastRandomVariationIndex = randomVariationIndex
        case 3:
            let all = FilterMode.allCases
            let idx = all.firstIndex(of: filterMode) ?? 0
            filterMode = all[(idx + 1) % all.count]
        case 53:
            deactivate()
        default:
            return false
        }

        // Any handled key may have mutated capture-loop state; republish.
        publishSnapshot()
        return true
    }

    private func allowsKeyRepeat(for keyCode: UInt16) -> Bool {
        switch keyCode {
        case 123, 124, 125, 126, 24, 27, 69, 78,
             30, 33: // ] and [ in randomizer mode
            return true
        default:
            return false
        }
    }

    func saveCurrentGrid() {
        let settings = AppSettings.shared
        var grid = gridState
        grid.isInverted = isInverted
        grid.horizontalMirrorMode = horizontalMirrorMode
        grid.verticalMirrorMode = verticalMirrorMode
        grid.isRounded = isRounded
        lastSavedURL = SVGExporter.save(grid: grid, to: settings.saveDirectory, filenameFormat: settings.filenameFormat)
        if let url = lastSavedURL {
            print("Saved: \(url.path)")
        }
    }

    private func startCaptureLoop() {
        let timer = DispatchSource.makeTimerSource(queue: captureQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(33))
        timer.setEventHandler { [weak self] in
            self?.captureFrame()
        }
        timer.resume()
        self.timer = timer
    }

    private func stopCaptureLoop() {
        timer?.cancel()
        timer = nil
    }

    private func captureFrame() {
        autoreleasepool {
            // Read all mutable state from the lock-protected snapshot exactly
            // once, so the rest of this frame works from a consistent,
            // thread-safe copy rather than racing the main thread.
            let snapshot = stateLock.withLock { $0 }
            let currentMouse = ScreenCaptureService.currentMouseLocation()
            let currentGridSize = snapshot.gridSize
            let currentViewportSize = snapshot.viewportSize
            let currentThreshold = snapshot.brightnessThreshold
            let currentFilterMode = snapshot.filterMode
            let currentInverted = snapshot.isInverted
            let currentHorizontalMirrorMode = snapshot.horizontalMirrorMode
            let currentVerticalMirrorMode = snapshot.verticalMirrorMode
            let currentRounded = snapshot.isRounded

            // Normalize the palette once. The filter and sampling layers
            // always see this original ordering — that's what produces the
            // structurally correct "which color belongs here" assignment.
            //
            // When the randomizer is active, we permute the swatches into
            // a different positional order for *rendering* only. Cell k
            // still gets the swatch the filter chose, but rendering looks
            // that index up in the permuted palette — so the same set of
            // colors ends up painted into different regions of the output.
            let baseNormalizedPalette = GridFilters.normalize(palette: snapshot.palette)
            let renderPalette = snapshot.isRandomizing
                ? PaletteVariator.variation(of: baseNormalizedPalette, seed: snapshot.randomVariationIndex)
                : baseNormalizedPalette

            let colors: [PixelColor]
            let paletteVotes: [Int?]?

            if currentFilterMode == .colorMatch {
                // Build the vote palette: non-transparent swatches plus the
                // map back to their indices in the full normalized palette.
                var voteColors: [PixelColor] = []
                var voteToFullIndex: [Int] = []
                for (index, swatch) in baseNormalizedPalette.enumerated() where !swatch.isTransparent {
                    voteColors.append(swatch.color)
                    voteToFullIndex.append(index)
                }

                if voteColors.isEmpty {
                    // No non-transparent swatches; falls back to average path.
                    guard let averages = captureService.colorGrid(
                        at: currentMouse,
                        size: currentViewportSize,
                        gridSize: currentGridSize
                    ) else { return }
                    colors = averages
                    paletteVotes = nil
                } else {
                    guard let bundle = captureService.colorAndVoteGrid(
                        at: currentMouse,
                        size: currentViewportSize,
                        gridSize: currentGridSize,
                        votePalette: voteColors
                    ) else { return }
                    colors = bundle.colors
                    paletteVotes = bundle.votes.map { vote in
                        guard let vote, vote >= 0, vote < voteToFullIndex.count else { return nil }
                        return voteToFullIndex[vote]
                    }
                }
            } else {
                guard let averages = captureService.colorGrid(
                    at: currentMouse,
                    size: currentViewportSize,
                    gridSize: currentGridSize
                ) else { return }
                colors = averages
                paletteVotes = nil
            }

            var newGrid = GridState(size: currentGridSize, palette: renderPalette)
            newGrid.cells = GridFilters.apply(
                currentFilterMode,
                colors: colors,
                gridSize: currentGridSize,
                palette: baseNormalizedPalette,
                threshold: currentThreshold,
                paletteVotes: paletteVotes
            )
            newGrid.isInverted = currentInverted
            newGrid.horizontalMirrorMode = currentHorizontalMirrorMode
            newGrid.verticalMirrorMode = currentVerticalMirrorMode
            newGrid.isRounded = currentRounded

            DispatchQueue.main.async { [weak self] in
                self?.gridState = newGrid
            }
        }
    }

    private func syncCurrentGridPresentation() {
        gridState.palette = palette
        gridState.isInverted = isInverted
        gridState.horizontalMirrorMode = horizontalMirrorMode
        gridState.verticalMirrorMode = verticalMirrorMode
        gridState.isRounded = isRounded
    }
}
