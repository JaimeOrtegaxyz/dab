import AppKit
import Combine

final class CaptureViewModel: ObservableObject {
    @Published var gridState = GridState(size: 16)
    @Published var gridSize: Int = 16
    @Published var viewportSize: CGFloat = 200
    @Published var brightnessThreshold: Float = 0.5
    @Published var filterMode: FilterMode = .threshold
    @Published var isInverted: Bool = false
    @Published var horizontalMirrorMode: HorizontalMirrorMode = .none
    @Published var verticalMirrorMode: VerticalMirrorMode = .none
    @Published var isRounded: Bool = false
    @Published var isActive: Bool = false
    @Published var lastSavedURL: URL?

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
        horizontalMirrorMode = settings.horizontalMirrorMode
        verticalMirrorMode = settings.verticalMirrorMode
    }

    func activate() {
        loadSettings()
        isInverted = false
        isRounded = false
        isActive = true
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
        case 4:
            horizontalMirrorMode = horizontalMirrorMode.next
        case 9:
            verticalMirrorMode = verticalMirrorMode.next
        case 15:
            isRounded.toggle()
        case 18:
            filterMode = .threshold
        case 19:
            filterMode = .otsu
        case 20:
            filterMode = .adaptive
        case 21:
            filterMode = .contrastBoost
        case 23:
            filterMode = .cleanThreshold
        case 22:
            filterMode = .edgeDetect
        case 26:
            filterMode = .floydSteinberg
        case 28:
            filterMode = .bayerDither
        case 3:
            let all = FilterMode.allCases
            let idx = all.firstIndex(of: filterMode) ?? 0
            filterMode = all[(idx + 1) % all.count]
        case 53:
            deactivate()
        default:
            return false
        }

        return true
    }

    private func allowsKeyRepeat(for keyCode: UInt16) -> Bool {
        switch keyCode {
        case 123, 124, 125, 126, 24, 27, 69, 78:
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
            let currentMouse = ScreenCaptureService.currentMouseLocation()
            let currentGridSize = gridSize
            let currentViewportSize = viewportSize
            let currentThreshold = brightnessThreshold
            let currentFilterMode = filterMode
            let currentInverted = isInverted
            let currentHorizontalMirrorMode = horizontalMirrorMode
            let currentVerticalMirrorMode = verticalMirrorMode
            let currentRounded = isRounded

            guard let brightness = captureService.brightnessGrid(
                at: currentMouse,
                size: currentViewportSize,
                gridSize: currentGridSize
            ) else { return }
            var newGrid = GridState(size: currentGridSize)
            newGrid.cells = GridFilters.apply(currentFilterMode, brightness: brightness, gridSize: currentGridSize, threshold: currentThreshold)
            newGrid.isInverted = currentInverted
            newGrid.horizontalMirrorMode = currentHorizontalMirrorMode
            newGrid.verticalMirrorMode = currentVerticalMirrorMode
            newGrid.isRounded = currentRounded

            DispatchQueue.main.async { [weak self] in
                self?.gridState = newGrid
            }
        }
    }
}
