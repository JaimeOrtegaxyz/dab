import AppKit
import CoreGraphics
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBarController = StatusBarController()
    private let hotkeyManager = HotkeyManager()
    private let viewModel = CaptureViewModel()
    private var overlayWindow: OverlayWindow?
    private var cursorTrackingTimer: DispatchSourceTimer?
    private var workspaceObserver: Any?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var isCursorHidden = false
    private var lastExternalApplication: NSRunningApplication?

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

        let currentPID = ProcessInfo.processInfo.processIdentifier
        if let frontmostApp = NSWorkspace.shared.frontmostApplication, frontmostApp.processIdentifier != currentPID {
            lastExternalApplication = frontmostApp
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.processIdentifier != currentPID
            else {
                return
            }

            self?.lastExternalApplication = app
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
        dismissOverlay()

        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
            self.workspaceObserver = nil
        }
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
        guard Permissions.ensureAccessibilityAccess() else {
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
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()
        window.invalidateCursorRects(for: hostingView)
        overlayWindow = window

        viewModel.startCapturing()
        startCursorTracking()
        startEventTap()
        setCursorHidden(true)

        DispatchQueue.main.async { [weak self] in
            self?.lastExternalApplication?.activate(options: [])
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
        stopEventTap()
        setCursorHidden(false)
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
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

    private func startEventTap() {
        stopEventTap()

        let events: [CGEventType] = [.leftMouseDown, .keyDown, .tapDisabledByTimeout, .tapDisabledByUserInput]
        let mask = events.reduce(CGEventMask(0)) { partialResult, eventType in
            partialResult | (1 << eventType.rawValue)
        }

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
            return appDelegate.handleEventTap(type: type, event: event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap. Accessibility permission is likely missing.")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        eventTapRunLoopSource = runLoopSource
    }

    private func stopEventTap() {
        if let runLoopSource = eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            eventTapRunLoopSource = nil
        }

        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func handleEventTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .leftMouseDown:
            viewModel.saveCurrentGrid()
            dismissOverlay()
            return nil
        case .keyDown:
            guard let keyEvent = NSEvent(cgEvent: event) else {
                return Unmanaged.passUnretained(event)
            }
            guard viewModel.handleKeyDown(keyEvent) else {
                return Unmanaged.passUnretained(event)
            }

            if !viewModel.isActive {
                dismissOverlay()
            } else {
                syncOverlayToCursor()
            }
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
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
