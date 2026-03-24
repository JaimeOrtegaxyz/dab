import AppKit
import ApplicationServices
import CoreGraphics

enum Permissions {
    static func ensureScreenRecordingAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        if CGRequestScreenCaptureAccess() {
            return true
        }

        showPermissionAlert()
        return false
    }

    static func ensureAccessibilityAccess() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Pixelatolor needs Screen Recording permission to capture screen content. If the macOS prompt appeared, approve it, then relaunch the app. Otherwise, enable it in System Settings → Privacy & Security → Screen Recording."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
