import AppKit
import Sparkle
import SwiftUI

final class StatusBarController {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var menuPanel: StatusMenuPanel?
    private var outsideClickMonitor: Any?

    var onActivate: (() -> Void)?
    var onHotkeyChanged: ((UInt32, UInt32) -> Bool)?
    var updaterController: SPUStandardUpdaterController?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // The dropdown is a themed panel, not an NSMenu (see StatusMenuView) —
        // so we drive it from the button's own click instead of `statusItem.menu`.
        if let button = statusItem?.button {
            button.image = Self.makeMenuBarImage()
            button.target = self
            button.action = #selector(toggleMenu)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
    }

    // MARK: - Themed dropdown

    @objc private func toggleMenu() {
        if menuPanel?.isVisible == true {
            hideMenu()
        } else {
            showMenu()
        }
    }

    private func showMenu() {
        let panel = menuPanel ?? makeMenuPanel()
        menuPanel = panel

        positionMenu(panel)
        // A background (accessory) app's window can't be key unless the app is
        // active, and without key focus the panel gets no keystrokes.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        statusItem?.button?.highlight(true)

        // Rebuild the menu's dismissal: a click in any *other* app (global
        // monitors never see our own status button or panel) closes it...
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.hideMenu()
        }
        // ...and a keyboard app-switch (which fires no mouse event) closes it too.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hideMenu),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func hideMenu() {
        guard let panel = menuPanel, panel.isVisible else { return }
        panel.orderOut(nil)
        statusItem?.button?.highlight(false)

        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
    }

    private func makeMenuPanel() -> StatusMenuPanel {
        let commands = [
            StatusMenuCommand("capture", dividerAfter: true) { [weak self] in
                self?.onActivate?()
            },
            StatusMenuCommand("settings…", key: ",") { [weak self] in
                self?.openSettings()
            },
            StatusMenuCommand("check for updates…", dividerAfter: true) { [weak self] in
                self?.updaterController?.checkForUpdates(nil)
            },
            StatusMenuCommand("quit dab", key: "q") { [weak self] in
                self?.quit()
            },
        ]

        let hosting = NSHostingView(
            rootView: StatusMenuView(commands: commands) { [weak self] in self?.hideMenu() }
        )
        hosting.setFrameSize(hosting.fittingSize)

        let panel = StatusMenuPanel(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        // Clear/non-opaque so the rounded plate — not a square window — casts
        // the shadow, matching a real menu's silhouette.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.appearance = NSAppearance(named: .aqua)
        return panel
    }

    /// Drop the plate just below the status item, left edge aligned to the
    /// button and clamped so it never runs off the screen's right edge.
    private func positionMenu(_ panel: NSPanel) {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = panel.frame.size
        let gap: CGFloat = 5

        var x = buttonRect.minX
        let y = buttonRect.minY - gap - size.height
        if let screen = buttonWindow.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(onHotkeyChanged: onHotkeyChanged)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 740),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        // Not movable by background: it would hijack drag-to-reorder on the
        // palette tiles (the window would move instead of the swatch). The
        // window is still movable from its title-bar region.
        window.isMovableByWindowBackground = false
        window.title = "dab Settings"
        // Force light appearance so the title text renders dark on the yellow case
        // (and so any system controls behind the SwiftUI view stay light-themed).
        window.appearance = NSAppearance(named: .aqua)

        // Visual effect background for glassmorphism
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .sidebar
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.frame = window.contentView!.bounds
        window.contentView!.addSubview(visualEffect)

        // SwiftUI hosting view on top
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = window.contentView!.bounds
        window.contentView!.addSubview(hostingView)

        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private static func makeMenuBarImage() -> NSImage? {
        let pointSize = NSSize(width: 18, height: 18)
        let fallback = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "dab")

        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "svg"),
              let image = NSImage(contentsOf: url) else {
            fallback?.isTemplate = true
            return fallback
        }

        image.size = pointSize
        image.isTemplate = true
        image.accessibilityDescription = "dab"
        return image
    }
}
