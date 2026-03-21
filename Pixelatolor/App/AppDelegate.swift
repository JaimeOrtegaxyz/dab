import AppKit
import CoreGraphics
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBarController = StatusBarController()
    private let hotkeyManager = HotkeyManager()
    private let viewModel = CaptureViewModel()
    private var overlayWindow: OverlayWindow?
    private var cursorTrackingTimer: DispatchSourceTimer?
    private var localKeyMonitor: Any?
    private var localClickMonitor: Any?
    private var isCursorHidden = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController.setup()
        statusBarController.onActivate = { [weak self] in
            self?.toggleOverlay()
        }
        statusBarController.onHotkeyChanged = { [weak self] keyCode, modifiers in
            self?.hotkeyManager.register(keyCode: keyCode, modifiers: modifiers)
        }

        hotkeyManager.callback = { [weak self] in
            self?.toggleOverlay()
        }
        let settings = AppSettings.shared
        hotkeyManager.register(keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
        dismissOverlay()
    }

    private func toggleOverlay() {
        if viewModel.isActive {
            dismissOverlay()
        } else {
            showOverlay()
        }
    }

    private func showOverlay() {
        guard Permissions.ensureScreenRecordingAccess() else {
            return
        }

        viewModel.activate()

        let mouseLocation = ScreenCaptureService.currentMouseLocation()
        let frame = frameForOverlay(at: mouseLocation)

        let window = OverlayWindow(contentRect: frame)
        let hostingView = CursorHidingHostingView(rootView:
            OverlayHostView(viewModel: viewModel)
        )
        window.contentView = hostingView
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.invalidateCursorRects(for: hostingView)
        overlayWindow = window

        viewModel.startCapturing()
        startCursorTracking()
        setCursorHidden(true)

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            self.viewModel.handleKeyDown(event)
            if !self.viewModel.isActive {
                self.dismissOverlay()
            } else {
                self.syncOverlayToCursor()
            }
            return nil
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.viewModel.saveCurrentGrid()
            self?.dismissOverlay()
            return nil
        }
    }

    private func frameForOverlay(at location: NSPoint) -> NSRect {
        let size = viewModel.viewportSize
        let barHeight = OverlayContentView.infoBarHeight
        let totalHeight = size + barHeight

        guard let screen = ScreenCaptureService.screen(containing: location) else {
            return NSRect(
                x: location.x - size / 2,
                y: location.y - size / 2 - barHeight,
                width: size,
                height: totalHeight
            )
        }

        let screenFrame = screen.frame
        let maxX = max(screenFrame.minX, screenFrame.maxX - size)
        let maxY = max(screenFrame.minY, screenFrame.maxY - totalHeight)
        let x = min(max(location.x - size / 2, screenFrame.minX), maxX)
        let y = min(max(location.y - size / 2 - barHeight, screenFrame.minY), maxY)

        return NSRect(x: x, y: y, width: size, height: totalHeight)
    }

    private func syncOverlayToCursor() {
        guard let overlayWindow else { return }

        let frame = frameForOverlay(at: ScreenCaptureService.currentMouseLocation())
        if overlayWindow.frame.size == frame.size {
            overlayWindow.setFrameOrigin(frame.origin)
        } else {
            overlayWindow.setFrame(frame, display: false)
        }
    }

    private func startCursorTracking() {
        stopCursorTracking()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            self?.syncOverlayToCursor()
        }
        timer.resume()
        cursorTrackingTimer = timer
    }

    private func stopCursorTracking() {
        cursorTrackingTimer?.cancel()
        cursorTrackingTimer = nil
    }

    private func dismissOverlay() {
        viewModel.deactivate()
        stopCursorTracking()
        setCursorHidden(false)
        overlayWindow?.orderOut(nil)
        overlayWindow = nil

        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }

    private func setCursorHidden(_ hidden: Bool) {
        guard hidden != isCursorHidden else { return }

        if hidden {
            NSCursor.hide()
            CGDisplayHideCursor(CGMainDisplayID())
        } else {
            CGDisplayShowCursor(CGMainDisplayID())
            NSCursor.unhide()
        }

        isCursorHidden = hidden
    }
}

struct OverlayHostView: View {
    @ObservedObject var viewModel: CaptureViewModel

    var body: some View {
        OverlayContentView(
            gridState: viewModel.gridState,
            gridSize: viewModel.gridSize,
            viewportSize: viewModel.viewportSize,
            filterMode: viewModel.filterMode,
            isInverted: viewModel.isInverted,
            horizontalMirrorMode: viewModel.horizontalMirrorMode,
            verticalMirrorMode: viewModel.verticalMirrorMode
        )
    }
}

final class CursorHidingHostingView<Content: View>: NSHostingView<Content> {
    private var invisibleCursor: NSCursor {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: image.size)).fill()
        image.unlockFocus()
        return NSCursor(image: image, hotSpot: .zero)
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: invisibleCursor)
    }
}
