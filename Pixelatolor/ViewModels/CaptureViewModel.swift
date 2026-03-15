import AppKit
import Combine

@Observable
final class CaptureViewModel {
    var gridState = GridState(size: 16)
    var gridSize: Int = 16
    var viewportSize: CGFloat = 200
    var brightnessThreshold: Float = 0.5
    var filterMode: FilterMode = .threshold
    var isActive: Bool = false
    var lastSavedURL: URL?

    private let captureService = ScreenCaptureService()
    private var timer: DispatchSourceTimer?
    private let captureQueue = DispatchQueue(label: "com.pixelatolor.capture", qos: .userInteractive)
    private var mouseLocation: NSPoint = .zero

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
    }

    /// Prepares settings and state. Call startCapturing() separately after the window is ready.
    func activate() {
        loadSettings()
        isActive = true
        mouseLocation = NSEvent.mouseLocation
    }

    /// Starts the capture loop. Call only after overlayWindowNumber is set.
    func startCapturing() {
        startCaptureLoop()
    }

    func deactivate() {
        isActive = false
        stopCaptureLoop()
    }

    func updateMouseLocation(_ point: NSPoint) {
        mouseLocation = point
    }

    // MARK: - Keyboard Controls

    func handleKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 123: // Left arrow — shrink viewport
            let step = AppSettings.shared.resizeStep
            viewportSize = max(60, viewportSize - step)
        case 124: // Right arrow — grow viewport
            let step = AppSettings.shared.resizeStep
            viewportSize = min(600, viewportSize + step)
        case 126: // Up arrow — increase grid size
            gridSize = min(32, gridSize + 1)
        case 125: // Down arrow — decrease grid size
            gridSize = max(4, gridSize - 1)
        case 24, 69: // + (main keyboard and numpad)
            brightnessThreshold = min(1.0, brightnessThreshold + 0.05)
        case 27, 78: // - (main keyboard and numpad)
            brightnessThreshold = max(0.0, brightnessThreshold - 0.05)
        case 49: // Spacebar — toggle inversion
            gridState.isInverted.toggle()
        case 4: // H — toggle horizontal mirror
            gridState.mirrorHorizontal.toggle()
        case 9: // V — toggle vertical mirror
            gridState.mirrorVertical.toggle()
        case 18: // 1 — Threshold
            filterMode = .threshold
        case 19: // 2 — Otsu
            filterMode = .otsu
        case 20: // 3 — Adaptive
            filterMode = .adaptive
        case 21: // 4 — Edge Detect
            filterMode = .edgeDetect
        case 23: // 5 — Floyd-Steinberg
            filterMode = .floydSteinberg
        case 22: // 6 — Bayer Dither
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

    func saveCurrentGrid() {
        let settings = AppSettings.shared
        lastSavedURL = SVGExporter.save(grid: gridState, to: settings.saveDirectory, filenameFormat: settings.filenameFormat)
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
        let currentMouse = mouseLocation
        let currentGridSize = gridSize
        let currentViewportSize = viewportSize
        let currentThreshold = brightnessThreshold
        let currentFilterMode = filterMode
        let currentInverted = gridState.isInverted
        let currentMirrorH = gridState.mirrorHorizontal
        let currentMirrorV = gridState.mirrorVertical

        let captureRect = ScreenCaptureService.cgRect(from: currentMouse, size: currentViewportSize)

        guard let image = captureService.capture(rect: captureRect) else { return }

        let brightness = image.brightnessGrid(gridSize: currentGridSize)
        var newGrid = GridState(size: currentGridSize)
        newGrid.cells = GridFilters.apply(currentFilterMode, brightness: brightness, gridSize: currentGridSize, threshold: currentThreshold)
        newGrid.isInverted = currentInverted
        newGrid.mirrorHorizontal = currentMirrorH
        newGrid.mirrorVertical = currentMirrorV

        DispatchQueue.main.async { [weak self] in
            self?.gridState = newGrid
        }
    }
}
