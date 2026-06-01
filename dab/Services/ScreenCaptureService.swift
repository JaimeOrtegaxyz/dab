import AppKit
import CoreGraphics
import CoreMedia
import CoreVideo
import ScreenCaptureKit

final class ScreenCaptureService: NSObject, SCStreamOutput, SCStreamDelegate {
    private struct FrameSnapshot {
        // Keep the owning sample buffer alive so the image buffer memory stays valid.
        let sampleBuffer: CMSampleBuffer
        let screenFrame: CGRect
        let pixelsPerPointX: CGFloat
        let pixelsPerPointY: CGFloat
    }

    private let controlQueue = DispatchQueue(label: "com.dab.screencapture.control")
    private let outputQueue = DispatchQueue(label: "com.dab.screencapture.output", qos: .userInteractive)
    private let frameLock = NSLock()
    // Guards the current stream identity + capture geometry so the output
    // callback can read them without taking controlQueue.sync — controlQueue is
    // held for the full duration of the blocking start/stop semaphore waits, so
    // reading through it would stall frame intake behind stream lifecycle.
    private let stateLock = NSLock()

    private var shareableContent: SCShareableContent?
    private var lastShareableContentRefresh: Date = .distantPast
    private var currentStream: SCStream?
    private var currentDisplayID: CGDirectDisplayID?
    private var currentCaptureState: (screenFrame: CGRect, pixelsPerPointX: CGFloat, pixelsPerPointY: CGFloat)?
    private var latestFrame: FrameSnapshot?
    private var pendingStopWorkItem: DispatchWorkItem?

    static func currentMouseLocation() -> NSPoint {
        NSEvent.mouseLocation
    }

    func prewarm() {
        controlQueue.async { [weak self] in
            guard let self else { return }
            _ = self.loadShareableContent(forceRefresh: self.shareableContent == nil)
        }
    }

    func prepare(at mouseLocation: NSPoint) {
        guard let screen = Self.screen(containing: mouseLocation) else {
            return
        }

        ensureStream(for: screen)
    }

    func stop(keepAliveFor delay: TimeInterval = 0) {
        controlQueue.async { [weak self] in
            self?.scheduleStop(after: delay)
        }
    }

    func brightnessGrid(at mouseLocation: NSPoint, size: CGFloat, gridSize: Int) -> [Float]? {
        guard let screen = Self.screen(containing: mouseLocation) else {
            return nil
        }

        ensureStream(for: screen)

        guard let snapshot = latestFrameSnapshot(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(snapshot.sampleBuffer) else {
            return nil
        }

        let cropRect = cropRect(around: mouseLocation, size: size, in: snapshot)
        return pixelBuffer.brightnessGrid(in: cropRect, gridSize: gridSize)
    }

    func colorGrid(at mouseLocation: NSPoint, size: CGFloat, gridSize: Int) -> [PixelColor]? {
        guard let screen = Self.screen(containing: mouseLocation) else {
            return nil
        }

        ensureStream(for: screen)

        guard let snapshot = latestFrameSnapshot(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(snapshot.sampleBuffer) else {
            return nil
        }

        let cropRect = cropRect(around: mouseLocation, size: size, in: snapshot)
        return pixelBuffer.colorGrid(in: cropRect, gridSize: gridSize)
    }

    /// Returns both per-cell RGB averages and per-cell palette-vote winners
    /// from a single locked pass of the latest captured frame. Both arrays
    /// come from the same `FrameSnapshot`, so callers don't risk pairing
    /// averages from one frame with votes from another.
    func colorAndVoteGrid(
        at mouseLocation: NSPoint,
        size: CGFloat,
        gridSize: Int,
        votePalette: [PixelColor]
    ) -> (colors: [PixelColor], votes: [Int?])? {
        guard let screen = Self.screen(containing: mouseLocation) else {
            return nil
        }

        ensureStream(for: screen)

        guard let snapshot = latestFrameSnapshot(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(snapshot.sampleBuffer) else {
            return nil
        }

        let cropRect = cropRect(around: mouseLocation, size: size, in: snapshot)
        return pixelBuffer.colorAndVoteGrid(
            in: cropRect,
            gridSize: gridSize,
            votePalette: votePalette
        )
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen,
              CMSampleBufferIsValid(sampleBuffer),
              isCompleteFrame(sampleBuffer) else {
            return
        }

        stateLock.lock()
        let state: (screenFrame: CGRect, pixelsPerPointX: CGFloat, pixelsPerPointY: CGFloat)? =
            (stream === currentStream) ? currentCaptureState : nil
        stateLock.unlock()

        guard let state else {
            return
        }

        frameLock.lock()
        latestFrame = FrameSnapshot(
            sampleBuffer: sampleBuffer,
            screenFrame: state.screenFrame,
            pixelsPerPointX: state.pixelsPerPointX,
            pixelsPerPointY: state.pixelsPerPointY
        )
        frameLock.unlock()
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Screen capture stream stopped: \(error.localizedDescription)")

        controlQueue.async { [weak self] in
            guard let self, stream === self.currentStream else {
                return
            }

            self.stateLock.lock()
            self.currentStream = nil
            self.currentCaptureState = nil
            self.stateLock.unlock()
            self.currentDisplayID = nil
            self.clearLatestFrame()
        }
    }

    private func ensureStream(for screen: NSScreen) {
        guard let displayID = Self.displayID(for: screen) else {
            return
        }

        controlQueue.sync {
            cancelPendingStop()
            // Also restart when the display's resolution/scale changed while the
            // same displayID stayed current — otherwise cropRect keeps using stale
            // pixelsPerPoint/screenFrame and samples the wrong region.
            let needsRestart = currentStream == nil
                || currentDisplayID != displayID
                || captureGeometryChanged(for: displayID)
            guard needsRestart else {
                return
            }

            startStream(for: displayID)
        }
    }

    /// Whether the live geometry of `displayID` no longer matches the stored
    /// capture state (resolution or scale-factor change). Runs on controlQueue.
    private func captureGeometryChanged(for displayID: CGDirectDisplayID) -> Bool {
        guard let state = currentCaptureState else { return true }
        guard let frame = Self.screenFrame(for: displayID), frame.width > 0, frame.height > 0 else {
            // Can't determine current geometry; don't thrash the stream.
            return false
        }
        let width = max(CGFloat(CGDisplayPixelsWide(displayID)), 1)
        let height = max(CGFloat(CGDisplayPixelsHigh(displayID)), 1)
        let pointEpsilon: CGFloat = 0.5
        if abs(state.screenFrame.minX - frame.minX) > pointEpsilon
            || abs(state.screenFrame.minY - frame.minY) > pointEpsilon
            || abs(state.screenFrame.width - frame.width) > pointEpsilon
            || abs(state.screenFrame.height - frame.height) > pointEpsilon {
            return true
        }
        let scaleEpsilon: CGFloat = 0.001
        return abs(state.pixelsPerPointX - width / frame.width) > scaleEpsilon
            || abs(state.pixelsPerPointY - height / frame.height) > scaleEpsilon
    }

    private func startStream(for displayID: CGDirectDisplayID) {
        stopCurrentStream()
        clearLatestFrame()

        let currentPID = ProcessInfo.processInfo.processIdentifier

        guard var resolvedShareableContent = shareableContent(for: displayID),
              var display = resolvedShareableContent.displays.first(where: { $0.displayID == displayID }) else {
            print("Failed to resolve shareable display for \(displayID).")
            return
        }

        var excludedApplications = resolvedShareableContent.applications.filter {
            $0.processID == currentPID
        }

        // If the app wasn't present in prewarmed/cached content, force-refresh once so
        // we don't accidentally capture our own overlay and create recursive noise.
        if excludedApplications.isEmpty,
           let refreshedContent = loadShareableContent(forceRefresh: true),
           let refreshedDisplay = refreshedContent.displays.first(where: { $0.displayID == displayID }) {
            resolvedShareableContent = refreshedContent
            display = refreshedDisplay
            excludedApplications = refreshedContent.applications.filter { $0.processID == currentPID }
        }

        if excludedApplications.isEmpty {
            print("Warning: current app PID \(currentPID) not found in shareable applications; capture may include overlay.")
        }

        let width = max(CGFloat(CGDisplayPixelsWide(displayID)), 1)
        let height = max(CGFloat(CGDisplayPixelsHigh(displayID)), 1)
        let frame = Self.screenFrame(for: displayID) ?? .zero
        guard frame.width > 0, frame.height > 0 else {
            return
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()
        configuration.width = Int(CGDisplayPixelsWide(displayID))
        configuration.height = Int(CGDisplayPixelsHigh(displayID))
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 2
        configuration.showsCursor = false
        configuration.capturesAudio = false

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)

        do {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        } catch {
            print("Failed to add screen stream output: \(error.localizedDescription)")
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        var startError: Error?

        stream.startCapture { error in
            startError = error
            semaphore.signal()
        }
        semaphore.wait()

        if let startError {
            print("Failed to start screen stream: \(startError.localizedDescription)")
            return
        }

        let captureState = (
            screenFrame: frame,
            pixelsPerPointX: width / frame.width,
            pixelsPerPointY: height / frame.height
        )
        stateLock.lock()
        currentStream = stream
        currentCaptureState = captureState
        stateLock.unlock()
        currentDisplayID = displayID
    }

    private func stopCurrentStream() {
        guard let stream = currentStream else {
            stateLock.lock()
            currentCaptureState = nil
            stateLock.unlock()
            currentDisplayID = nil
            clearLatestFrame()
            return
        }

        stateLock.lock()
        currentStream = nil
        currentCaptureState = nil
        stateLock.unlock()
        currentDisplayID = nil
        clearLatestFrame()

        do {
            try stream.removeStreamOutput(self, type: .screen)
        } catch {
            print("Failed to remove screen stream output: \(error.localizedDescription)")
        }

        let semaphore = DispatchSemaphore(value: 0)
        stream.stopCapture { error in
            if let error {
                print("Failed to stop screen stream: \(error.localizedDescription)")
            }
            semaphore.signal()
        }
        semaphore.wait()
    }

    private func scheduleStop(after delay: TimeInterval) {
        pendingStopWorkItem?.cancel()
        pendingStopWorkItem = nil

        guard delay > 0 else {
            stopCurrentStream()
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.stopCurrentStream()
            self.pendingStopWorkItem = nil
        }
        pendingStopWorkItem = workItem
        controlQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelPendingStop() {
        pendingStopWorkItem?.cancel()
        pendingStopWorkItem = nil
    }

    private func isCompleteFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]],
            let attachments = attachmentsArray.first else {
            return false
        }

        let statusRaw: Int
        if let statusNumber = attachments[.status] as? NSNumber {
            statusRaw = statusNumber.intValue
        } else if let statusInt = attachments[.status] as? Int {
            statusRaw = statusInt
        } else {
            return false
        }

        guard let status = SCFrameStatus(rawValue: statusRaw) else {
            return false
        }

        return status == .complete
    }

    private func latestFrameSnapshot() -> FrameSnapshot? {
        frameLock.lock()
        let snapshot = latestFrame
        frameLock.unlock()
        return snapshot
    }

    private func clearLatestFrame() {
        frameLock.lock()
        latestFrame = nil
        frameLock.unlock()
    }

    private func fetchShareableContent() -> SCShareableContent? {
        let semaphore = DispatchSemaphore(value: 0)
        var fetchedContent: SCShareableContent?

        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
            if let error {
                print("Failed to load shareable content: \(error.localizedDescription)")
            }

            fetchedContent = content
            semaphore.signal()
        }

        semaphore.wait()
        return fetchedContent
    }

    private func loadShareableContent(forceRefresh: Bool) -> SCShareableContent? {
        if !forceRefresh, let shareableContent {
            return shareableContent
        }

        guard let fetchedContent = fetchShareableContent() else {
            return shareableContent
        }

        shareableContent = fetchedContent
        lastShareableContentRefresh = Date()
        return fetchedContent
    }

    private func shareableContent(for displayID: CGDirectDisplayID) -> SCShareableContent? {
        if let cached = shareableContent,
           cached.displays.contains(where: { $0.displayID == displayID }) {
            return cached
        }

        let shouldForceRefresh = Date().timeIntervalSince(lastShareableContentRefresh) > 10
        guard let refreshed = loadShareableContent(forceRefresh: shouldForceRefresh || shareableContent == nil) else {
            return nil
        }

        if refreshed.displays.contains(where: { $0.displayID == displayID }) {
            return refreshed
        }

        let forcedRefresh = loadShareableContent(forceRefresh: true)
        return forcedRefresh?.displays.contains(where: { $0.displayID == displayID }) == true ? forcedRefresh : nil
    }

    private func cropRect(around mouseLocation: NSPoint, size: CGFloat, in snapshot: FrameSnapshot) -> CGRect {
        let screenFrame = snapshot.screenFrame
        let maxX = max(screenFrame.minX, screenFrame.maxX - size)
        let maxY = max(screenFrame.minY, screenFrame.maxY - size)
        let originX = min(max(mouseLocation.x - size / 2, screenFrame.minX), maxX)
        let originY = min(max(mouseLocation.y - size / 2, screenFrame.minY), maxY)

        let localX = originX - screenFrame.minX
        let localYFromTop = screenFrame.maxY - originY - size

        let x = floor(localX * snapshot.pixelsPerPointX)
        let y = floor(localYFromTop * snapshot.pixelsPerPointY)
        let width = ceil(size * snapshot.pixelsPerPointX)
        let height = ceil(size * snapshot.pixelsPerPointY)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return displayID.uint32Value
    }

    private static func screenFrame(for targetDisplayID: CGDirectDisplayID) -> CGRect? {
        NSScreen.screens.first { displayID(for: $0) == targetDisplayID }?.frame
    }

    static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }
}
