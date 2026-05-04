import AppKit
import CoreText

// Register bundled fonts before any UI is created so .font(.custom("Inconsolata", …))
// resolves correctly across the app.
if let fontURL = Bundle.main.url(forResource: "Inconsolata", withExtension: "ttf") {
    CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
}

// Pure AppKit entry point — no SwiftUI App scene, so no window opens on launch.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
