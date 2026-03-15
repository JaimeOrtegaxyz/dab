import AppKit

// Pure AppKit entry point — no SwiftUI App scene, so no window opens on launch.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
