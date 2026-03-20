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
    @Published var isActive: Bool = false
    @Published var lastSavedURL: URL?

    private let captureService = ScreenCaptureService()
    private var timer: DispatchSourceTimer?
    private let captureQueue = DispatchQueue(label: "com.pixelatolor.capture", qos: .userInteractive)

    var overlayWindowNumber: Int {
        get { captureService.excludeWindowNumber }
        set { captureService.excludeWindowNumber = newValue }
    }

    func loadSettings() {
        let settings = AppSettings.shared
        gridSize = settings.gridSize
        viewportSize = settings.viewportSize
        brightnessThreshold = settings.brightnessThreshold
        filterMode = settings.filterMode
        horizontalMirrorMode = settings.horizontalMirrorMode
        verticalMirrorMode = settings.verticalMirrorMode
    }

    /// Prepares settings and state. Call startCapturing() separately after the window is ready.
    func activate() {
        loadSettings()
        isInverted = false
        isActive = true
    }

    /// Starts the capture loop. Call only after overlayWindowNumber is set.
    func startCapturing() {
        startCaptureLoop()
    }

    func deactivate() {
        isActive = false
        stopCaptureLoop()
    }

    // MARK: - Keyboard Controls

    func handleKeyDown(_ event: NSEvent) {
        if event.isARepeat && !allowsKeyRepeat(for: event.keyCode) {
            return
        }

        let isCoarseAdjustment = event.modifierFlags.contains(.shift)
        let viewportStep = AppSettings.shared.resizeStep * (isCoarseAdjustment ? 4 : 1)
        let gridStep = isCoarseAdjustment ? 4 : 1
        let thresholdStep: Float = 0.05 * (isCoarseAdjustment ? 4 : 1)

        switch event.keyCode {
        case 123: // Left arrow — shrink viewport
            viewportSize = max(60, viewportSize - viewportStep)
        case 124: // Right arrow — grow viewport
            viewportSize = min(600, viewportSize + viewportStep)
        case 126: // Up arrow — increase grid size
            gridSize = min(32, gridSize + gridStep)
        case 125: // Down arrow — decrease grid size
            gridSize = max(4, gridSize - gridStep)
        case 24, 69: // + (main keyboard and numpad)
            brightnessThreshold = min(1.0, brightnessThreshold + thresholdStep)
        case 27, 78: // - (main keyboard and numpad)
            brightnessThreshold = max(0.0, brightnessThreshold - thresholdStep)
        case 49: // Spacebar — toggle inversion
            isInverted.toggle()
        case 4: // H — cycle horizontal mirror
            horizontalMirrorMode = horizontalMirrorMode.next
        case 9: // V — cycle vertical mirror
            verticalMirrorMode = verticalMirrorMode.next
        case 18: // 1 — Threshold
            filterMode = .threshold
        case 19: // 2 — Otsu
            filterMode = .otsu
        case 20: // 3 — Adaptive
            filterMode = .adaptive
        case 21: // 4 — Contrast
            filterMode = .contrastBoost
        case 23: // 5 — Clean
            filterMode = .cleanThreshold
        case 22: // 6 — Edge Detect
            filterMode = .edgeDetect
        case 26: // 7 — Floyd-Steinberg
            filterMode = .floydSteinberg
        case 28: // 8 — Ordered Dither
            filterMode = .bayerDither
        case 3: // F — cycle filter
            let all = FilterMode.allCases
            let idx = all.firstIndex(of: filterMode) ?? 0
            filterMode = all[(idx + 1) % all.count]
        case 53: // Escape — dismiss
            deactivate()
        default:
            break
        }
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
        lastSavedURL = SVGExporter.save(grid: grid, to: settings.saveDirectory, filenameFormat: settings.filenameFormat)
        if let url = lastSavedURL {
            print("Saved: \(url.path)")
        }
    }

    // MARK: - Capture Loop

    private func startCaptureLoop() {
        let timer = DispatchSource.makeTimerSource(queue: captureQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(33)) // ~30fps
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
        let currentMouse = ScreenCaptureService.currentMouseLocation()
        let currentGridSize = gridSize
        let currentViewportSize = viewportSize
        let currentThreshold = brightnessThreshold
        let currentFilterMode = filterMode
        let currentInverted = isInverted
        let currentHorizontalMirrorMode = horizontalMirrorMode
        let currentVerticalMirrorMode = verticalMirrorMode

        let captureRect = ScreenCaptureService.cgRect(from: currentMouse, size: currentViewportSize)

        guard let image = captureService.capture(rect: captureRect) else { return }

        let brightness = image.brightnessGrid(gridSize: currentGridSize)
        var newGrid = GridState(size: currentGridSize)
        newGrid.cells = GridFilters.apply(currentFilterMode, brightness: brightness, gridSize: currentGridSize, threshold: currentThreshold)
        newGrid.isInverted = currentInverted
        newGrid.horizontalMirrorMode = currentHorizontalMirrorMode
        newGrid.verticalMirrorMode = currentVerticalMirrorMode

        DispatchQueue.main.async { [weak self] in
            self?.gridState = newGrid
        }
    }
}
