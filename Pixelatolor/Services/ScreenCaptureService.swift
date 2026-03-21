import AppKit
import CoreGraphics
import ScreenCaptureKit

final class ScreenCaptureService {
    private struct CaptureRequest {
        let filter: SCContentFilter
        let configuration: SCStreamConfiguration
    }

    private let stateQueue = DispatchQueue(label: "com.pixelatolor.screencapture.state")
    private var shareableContent: SCShareableContent?
    private var lastContentRefresh: Date = .distantPast
    private let contentRefreshInterval: TimeInterval = 5

    static func currentMouseLocation() -> NSPoint {
        NSEvent.mouseLocation
    }

    func capture(at mouseLocation: NSPoint, size: CGFloat) -> CGImage? {
        guard let request = makeCaptureRequest(at: mouseLocation, size: size) else {
            return nil
        }

        let semaphore = DispatchSemaphore(value: 0)
        var capturedImage: CGImage?

        SCScreenshotManager.captureImage(
            contentFilter: request.filter,
            configuration: request.configuration
        ) { image, error in
            if let error {
                print("Failed to capture screenshot: \(error.localizedDescription)")
            }

            capturedImage = image
            semaphore.signal()
        }

        semaphore.wait()
        return capturedImage
    }

    private func makeCaptureRequest(at mouseLocation: NSPoint, size: CGFloat) -> CaptureRequest? {
        guard
            let screen = Self.screen(containing: mouseLocation),
            let display = shareableDisplay(for: screen)
        else {
            return nil
        }

        let screenFrame = screen.frame
        let maxX = max(screenFrame.minX, screenFrame.maxX - size)
        let maxY = max(screenFrame.minY, screenFrame.maxY - size)
        let x = min(max(mouseLocation.x - size / 2, screenFrame.minX), maxX)
        let y = min(max(mouseLocation.y - size / 2, screenFrame.minY), maxY)

        let config = SCStreamConfiguration()
        let scale = max(screen.backingScaleFactor, 1)
        config.width = Int((size * scale).rounded(.up))
        config.height = Int((size * scale).rounded(.up))
        config.sourceRect = CGRect(
            x: x - screenFrame.minX,
            y: screenFrame.maxY - y - size,
            width: size,
            height: size
        )
        config.showsCursor = false
        config.capturesAudio = false

        let excludedApps = currentShareableContent()?.applications.filter {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        } ?? []
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApps,
            exceptingWindows: []
        )

        return CaptureRequest(filter: filter, configuration: config)
    }

    private func shareableDisplay(for screen: NSScreen) -> SCDisplay? {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        if let display = currentShareableContent()?.displays.first(where: { $0.displayID == displayID.uint32Value }) {
            return display
        }

        return refreshShareableContent()?.displays.first(where: { $0.displayID == displayID.uint32Value })
    }

    private func currentShareableContent() -> SCShareableContent? {
        let shouldRefresh = stateQueue.sync {
            shareableContent == nil || Date().timeIntervalSince(lastContentRefresh) > contentRefreshInterval
        }

        if shouldRefresh {
            return refreshShareableContent()
        }

        return stateQueue.sync { shareableContent }
    }

    private func refreshShareableContent() -> SCShareableContent? {
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

        stateQueue.sync {
            shareableContent = fetchedContent
            lastContentRefresh = Date()
        }

        return fetchedContent
    }

    static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }
}
