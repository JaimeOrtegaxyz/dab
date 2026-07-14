import AppKit
import CoreGraphics
import Sparkle
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBarController = StatusBarController()
    private let hotkeyManager = HotkeyManager()
    private let viewModel = CaptureViewModel()
    private var updaterController: SPUStandardUpdaterController!
    private var overlayWindow: OverlayWindow?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var localKeyMonitor: Any?
    private var cursorTrackingTimer: DispatchSourceTimer?
    private var workspaceObserver: Any?
    private var isCursorHidden = false
    private var cursorHideDepth = 0
    private var lastExternalApplication: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        statusBarController.updaterController = updaterController
        statusBarController.setup()
        statusBarController.onActivate = { [weak self] in
            self?.toggleOverlay()
        }
        statusBarController.onHotkeyChanged = { [weak self] keyCode, modifiers in
            self?.hotkeyManager.register(keyCode: keyCode, modifiers: modifiers) ?? false
        }

        hotkeyManager.callback = { [weak self] in
            self?.toggleOverlay()
        }
        let settings = AppSettings.shared
        hotkeyManager.register(keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers)

        // Register dab as a login item on first run so it starts with the user's
        // session; thereafter the Settings toggle owns this choice.
        LoginItemService.applyDefaultIfNeeded()

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

        DispatchQueue.main.async { [weak self] in
            Permissions.promptForRequiredPermissionsOnFirstLaunch()
            self?.viewModel.prewarmCaptureResources()
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
        guard overlayWindow == nil else { return }

        guard Permissions.ensureScreenRecordingAccess() else {
            return
        }
        guard Permissions.ensureAccessibilityAccess() else {
            Permissions.showInteractionPermissionAlert()
            return
        }

        viewModel.activate()
        setCursorHidden(true)
        guard startEventTap() else {
            setCursorHidden(false)
            viewModel.deactivate()
            Permissions.showInteractionPermissionAlert()
            return
        }

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
        installLocalKeyMonitor()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            NSApp.activate(ignoringOtherApps: true)
            guard self.viewModel.isActive, self.isCursorHidden else {
                return
            }

            // Some apps force-show the cursor on activation; re-hide if we're still capturing.
            self.hideCursorOnce()
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
        removeLocalKeyMonitor()
        setCursorHidden(false)
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        lastExternalApplication?.activate(options: [])
    }

    private func installLocalKeyMonitor() {
        removeLocalKeyMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.viewModel.isActive else { return event }

            let handled = self.viewModel.handleKeyDown(event)
            if !self.viewModel.isActive {
                self.dismissOverlay()
                return nil
            }

            if handled {
                self.syncOverlayToCursor()
                return nil
            }

            return event
        }
    }

    private func removeLocalKeyMonitor() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    private func setCursorHidden(_ hidden: Bool) {
        if hidden {
            guard !isCursorHidden else { return }
            hideCursorOnce()
            isCursorHidden = true
        } else {
            guard isCursorHidden else { return }
            showCursorCompletely()
            isCursorHidden = false
        }
    }

    private func hideCursorOnce() {
        NSCursor.hide()
        for displayID in activeDisplayIDs() {
            CGDisplayHideCursor(displayID)
        }
        cursorHideDepth += 1
    }

    private func showCursorCompletely() {
        guard cursorHideDepth > 0 else { return }

        for _ in 0..<cursorHideDepth {
            for displayID in activeDisplayIDs() {
                CGDisplayShowCursor(displayID)
            }
            NSCursor.unhide()
        }
        cursorHideDepth = 0
    }

    private func activeDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return [CGMainDisplayID()]
        }

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displayIDs, &count) == .success else {
            return [CGMainDisplayID()]
        }

        return Array(displayIDs.prefix(Int(count)))
    }

    @discardableResult
    private func startEventTap() -> Bool {
        stopEventTap()

        let events: [CGEventType] = [
            .leftMouseDown,
            .leftMouseUp,
            .leftMouseDragged,
            .rightMouseDown,
            .rightMouseUp,
            .rightMouseDragged,
            .otherMouseDown,
            .otherMouseUp,
            .otherMouseDragged,
            .scrollWheel,
            .keyDown,
            .keyUp,
            .flagsChanged,
            .tapDisabledByTimeout,
            .tapDisabledByUserInput,
        ]
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
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        eventTapRunLoopSource = runLoopSource
        return true
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
        // Re-enable the tap whenever it's still installed, independent of active
        // state — the OS can disable it on timeout/user-input and we must recover
        // even if this arrives while inactive but before teardown runs.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard viewModel.isActive else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .leftMouseDown:
            viewModel.saveCurrentGrid()
            // Defer teardown: dismissOverlay() invalidates this very event tap, so
            // running it synchronously tears down the mach port from inside its own
            // CGEventTapCallBack. Hop to the next main-runloop turn so the callback
            // fully unwinds first.
            DispatchQueue.main.async { [weak self] in self?.dismissOverlay() }
            return nil
        case .leftMouseUp,
             .leftMouseDragged,
             .rightMouseDown,
             .rightMouseUp,
             .rightMouseDragged,
             .otherMouseDown,
             .otherMouseUp,
             .otherMouseDragged,
             .scrollWheel,
             .keyUp,
             .flagsChanged:
            return nil
        case .keyDown:
            if let keyEvent = NSEvent(cgEvent: event) {
                _ = viewModel.handleKeyDown(keyEvent)

                if !viewModel.isActive {
                    // Same reason as .leftMouseDown: defer teardown out of the tap callback.
                    DispatchQueue.main.async { [weak self] in self?.dismissOverlay() }
                } else {
                    syncOverlayToCursor()
                }
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
            verticalMirrorMode: viewModel.verticalMirrorMode,
            isRandomizing: viewModel.isRandomizing,
            randomVariationIndex: viewModel.randomVariationIndex
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
