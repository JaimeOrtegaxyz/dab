import AppKit
import ApplicationServices
import CoreGraphics

enum Permissions {
    private static let didPromptForInitialPermissionsKey = "didPromptForInitialPermissions"
    private static var didRequestAccessibilityThisSession = false

    private enum RequiredPermission {
        case screenRecording
        case accessibility

        var title: String {
            switch self {
            case .screenRecording:
                return "Screen Recording"
            case .accessibility:
                return "Accessibility"
            }
        }
    }

    static func promptForRequiredPermissionsOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didPromptForInitialPermissionsKey) else {
            return
        }

        defaults.set(true, forKey: didPromptForInitialPermissionsKey)

        let missingPermissions = missingRequiredPermissions()
        guard !missingPermissions.isEmpty else {
            return
        }

        for permission in missingPermissions {
            guard showStartupPermissionExplainer(for: permission) else {
                break
            }
        }
    }

    static func ensureScreenRecordingAccess() -> Bool {
        if hasScreenRecordingAccess() {
            return true
        }

        if CGRequestScreenCaptureAccess() {
            return true
        }

        showPermissionAlert()
        return false
    }

    static func ensureAccessibilityAccess() -> Bool {
        if hasAccessibilityAccess() {
            return true
        }

        guard !didRequestAccessibilityThisSession else {
            return false
        }

        didRequestAccessibilityThisSession = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return hasAccessibilityAccess()
    }

    private static func hasScreenRecordingAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    private static func hasAccessibilityAccess() -> Bool {
        AXIsProcessTrusted()
    }

    private static func missingRequiredPermissions() -> [RequiredPermission] {
        var permissions: [RequiredPermission] = []

        if !hasScreenRecordingAccess() {
            permissions.append(.screenRecording)
        }

        if !hasAccessibilityAccess() {
            permissions.append(.accessibility)
        }

        return permissions
    }

    private static func showStartupPermissionExplainer(for permission: RequiredPermission) -> Bool {
        let alert = NSAlert()
        alert.messageText = "\(permission.title) Permission Needed"
        alert.informativeText = startupPromptMessage(for: permission)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Go and allow this")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            return false
        }

        openSystemSettings(for: permission)
        requestPermission(permission)
        return true
    }

    private static func startupPromptMessage(for permission: RequiredPermission) -> String {
        switch permission {
        case .screenRecording:
            return "dab samples your screen live to build the pixel preview. Allow Screen Recording in System Settings, then relaunch dab if macOS asks for it."
        case .accessibility:
            return "dab needs Accessibility to capture keyboard shortcuts and keep the preview interaction modal. Allow it in System Settings."
        }
    }

    private static func requestPermission(_ permission: RequiredPermission) {
        switch permission {
        case .screenRecording:
            _ = CGRequestScreenCaptureAccess()
        case .accessibility:
            _ = ensureAccessibilityAccess()
        }
    }

    private static func openSystemSettings(for permission: RequiredPermission) {
        guard let url = systemSettingsURL(for: permission) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func systemSettingsURL(for permission: RequiredPermission) -> URL? {
        switch permission {
        case .screenRecording:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }

    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "dab needs Screen Recording permission to capture screen content. If the macOS prompt appeared, approve it, then relaunch the app. Otherwise, enable it in System Settings → Privacy & Security → Screen Recording."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Go and allow this")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemSettings(for: .screenRecording)
        }
    }

    static func showInteractionPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Permission Needed for Overlay Controls"
        alert.informativeText = "dab could not install its global input handler. Enable Accessibility for dab, and if it still fails, also allow Input Monitoring. Then relaunch dab."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Open Input Monitoring")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemSettings(for: .accessibility)
        } else if response == .alertSecondButtonReturn,
                  let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
