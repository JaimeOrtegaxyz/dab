import AppKit
import CoreGraphics
import CoreMedia
import CoreVideo
import ScreenCaptureKit

final class ScreenCaptureService: NSObject, SCStreamOutput, SCStreamDelegate {
    private struct FrameSnapshot {
        let pixelBuffer: CVPixelBuffer
        let screenFrame: CGRect
        let pixelsPerPointX: CGFloat
        let pixelsPerPointY: CGFloat
    }

    private let controlQueue = DispatchQueue(label: "com.pixelatolor.screencapture.control")
    private let outputQueue = DispatchQueue(label: "com.pixelatolor.screencapture.output", qos: .userInteractive)
    private let frameLock = NSLock()

    private var shareableContent: SCShareableContent?
    private var currentStream: SCStream?
    private var currentDisplayID: CGDirectDisplayID?
    private var latestFrame: FrameSnapshot?

    static func currentMouseLocation() -> NSPoint {
        NSEvent.mouseLocation
    }

    func prepare(at mouseLocation: NSPoint) {
        guard let screen = Self.screen(containing: mouseLocation) else {
            return
        }

        ensureStream(for: screen)
    }

    func stop() {
        controlQueue.async { [weak self] in
            self?.stopCurrentStream()
        }
    }

    func brightnessGrid(at mouseLocation: NSPoint, size: CGFloat, gridSize: Int) -> [Float]? {
        guard let screen = Self.screen(containing: mouseLocation) else {
            return nil
        }

        ensureStream(for: screen)

        guard let snapshot = latestFrameSnapshot() else {
            return nil
        }

        let cropRect = cropRect(around: mouseLocation, size: size, in: snapshot)
        return snapshot.pixelBuffer.brightnessGrid(in: cropRect, gridSize: gridSize)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen, CMSampleBufferIsValid(sampleBuffer) else {
            return
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let state = controlQueue.sync { () -> (screenFrame: CGRect, pixelsPerPointX: CGFloat, pixelsPerPointY: CGFloat)? in
            guard stream === currentStream, let displayID = currentDisplayID else {
                return nil
            }

            let width = max(CGFloat(CGDisplayPixelsWide(displayID)), 1)
            let height = max(CGFloat(CGDisplayPixelsHigh(displayID)), 1)
            let frame = Self.screenFrame(for: displayID) ?? .zero
            guard frame.width > 0, frame.height > 0 else {
                return nil
            }

            return (
                screenFrame: frame,
                pixelsPerPointX: width / frame.width,
                pixelsPerPointY: height / frame.height
            )
        }

        guard let state else {
            return
        }

        frameLock.lock()
        latestFrame = FrameSnapshot(
            pixelBuffer: pixelBuffer,
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

            self.currentStream = nil
            self.currentDisplayID = nil
            self.clearLatestFrame()
        }
    }

    private func ensureStream(for screen: NSScreen) {
        guard let displayID = Self.displayID(for: screen) else {
            return
        }

        controlQueue.sync {
            let needsRestart = currentStream == nil || currentDisplayID != displayID
            guard needsRestart else {
                return
            }

            startStream(for: screen, displayID: displayID)
        }
    }

    private func startStream(for screen: NSScreen, displayID: CGDirectDisplayID) {
        stopCurrentStream()
        clearLatestFrame()

        shareableContent = fetchShareableContent()

        guard
            let shareableContent,
            let display = shareableContent.displays.first(where: { $0.displayID == displayID })
        else {
            print("Failed to resolve shareable display for \(displayID).")
            return
        }

        let excludedApplications = shareableContent.applications.filter {
            $0.processID == ProcessInfo.processInfo.processIdentifier
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

        currentStream = stream
        currentDisplayID = displayID
    }

    private func stopCurrentStream() {
        guard let stream = currentStream else {
            currentDisplayID = nil
            clearLatestFrame()
            return
        }

        currentStream = nil
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
