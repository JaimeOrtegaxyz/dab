import CoreGraphics
import AppKit

final class ScreenCaptureService {
    /// Window number to exclude from capture (the overlay window)
    var excludeWindowNumber: Int = 0

    /// Captures a region of the screen, excluding the overlay window.
    func capture(rect: CGRect) -> CGImage? {
        // optionOnScreenBelowWindow captures everything on screen below (and not including)
        // the specified window. Since our overlay is .floating level, all normal app windows
        // are below it, so this gives us the full screen minus our overlay.
        let windowID = CGWindowID(excludeWindowNumber)
        return CGWindowListCreateImage(
            rect,
            .optionOnScreenBelowWindow,
            windowID,
            [.nominalResolution]
        )
    }

    /// Converts NSEvent mouse location (bottom-left origin) to CG coordinates (top-left origin)
    static func cgRect(from nsPoint: NSPoint, size: CGFloat) -> CGRect {
        guard let mainScreen = NSScreen.main else {
            return .zero
        }
        let screenHeight = mainScreen.frame.height
        let cgY = screenHeight - nsPoint.y
        return CGRect(
            x: nsPoint.x - size / 2,
            y: cgY - size / 2,
            width: size,
            height: size
        )
    }
}
