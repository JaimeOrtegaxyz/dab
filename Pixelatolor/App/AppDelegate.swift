import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBarController = StatusBarController()
    private let hotkeyManager = HotkeyManager()
    private let viewModel = CaptureViewModel()
    private var overlayWindow: OverlayWindow?
    private var mouseMovedMonitor: Any?
    private var localMouseMonitor: Any?
    private var localKeyMonitor: Any?
    private var localClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup status bar
        statusBarController.setup()
        statusBarController.onActivate = { [weak self] in
            self?.toggleOverlay()
        }
        statusBarController.onHotkeyChanged = { [weak self] keyCode, modifiers in
            self?.hotkeyManager.register(keyCode: keyCode, modifiers: modifiers)
        }

        // Register global hotkey
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

    // MARK: - Overlay Management

    private func toggleOverlay() {
        if viewModel.isActive {
            dismissOverlay()
        } else {
            showOverlay()
        }
    }

    private func showOverlay() {
        // 1. Prepare state (no capture loop yet)
        viewModel.activate()

        let settings = AppSettings.shared
        viewModel.gridState.mirrorHorizontal = settings.mirrorHorizontal
        viewModel.gridState.mirrorVertical = settings.mirrorVertical

        // 2. Create overlay window
        let size = viewModel.viewportSize
        let barHeight = OverlayContentView.infoBarHeight
        let mouseLocation = NSEvent.mouseLocation
        let frame = NSRect(
            x: mouseLocation.x - size / 2,
            y: mouseLocation.y - size / 2 - barHeight,
            width: size,
            height: size + barHeight
        )

        let window = OverlayWindow(contentRect: frame)
        let hostingView = NSHostingView(rootView:
            OverlayHostView(viewModel: viewModel)
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        overlayWindow = window

        // 3. Set window number THEN start capture loop
        viewModel.overlayWindowNumber = window.windowNumber
        viewModel.startCapturing()

        mouseMovedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(NSEvent.mouseLocation)
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(NSEvent.mouseLocation)
            return event
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            self.viewModel.handleKeyDown(event)
            if !self.viewModel.isActive {
                self.dismissOverlay()
            }
            return nil
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.viewModel.saveCurrentGrid()
            self?.dismissOverlay()
            return nil
        }
    }

    private func handleMouseMoved(_ location: NSPoint) {
        viewModel.updateMouseLocation(location)

        let size = viewModel.viewportSize
        let barHeight = OverlayContentView.infoBarHeight
        let frame = NSRect(
            x: location.x - size / 2,
            y: location.y - size / 2 - barHeight,
            width: size,
            height: size + barHeight
        )
        overlayWindow?.setFrame(frame, display: true)
    }

    private func dismissOverlay() {
        viewModel.deactivate()
        overlayWindow?.orderOut(nil)
        overlayWindow = nil

        if let monitor = mouseMovedMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMovedMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }
}

struct OverlayHostView: View {
    @Bindable var viewModel: CaptureViewModel

    var body: some View {
        OverlayContentView(
            gridState: viewModel.gridState,
            gridSize: viewModel.gridSize,
            viewportSize: viewModel.viewportSize,
            filterMode: viewModel.filterMode
        )
    }
}
