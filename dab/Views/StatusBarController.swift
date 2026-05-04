import AppKit
import SwiftUI

final class StatusBarController {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    var onActivate: (() -> Void)?
    var onHotkeyChanged: ((UInt32, UInt32) -> Void)?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = Self.makeMenuBarImage()
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture", action: #selector(activateCapture), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit dab", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu
    }

    @objc private func activateCapture() {
        onActivate?()
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
        window.isMovableByWindowBackground = true
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
