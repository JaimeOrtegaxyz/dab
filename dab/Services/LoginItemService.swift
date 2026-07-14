import ServiceManagement

/// Wraps `SMAppService.mainApp` so the rest of the app can treat "start dab at
/// login" as a simple on/off. The actual Login Item registration — the row
/// macOS shows in System Settings > General > Login Items — is the source of
/// truth: SMAppService persists it across launches, so there is no UserDefaults
/// mirror to keep in sync.
enum LoginItemService {
    /// One-shot flag so the "default on" behaviour is applied exactly once and
    /// never overrides a later user choice.
    private static let didApplyDefaultKey = "didApplyLoginItemDefault"

    /// Whether dab is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register or unregister dab as a login item. Returns whether the request
    /// succeeded; errors are logged and swallowed so the caller can simply
    /// re-read `isEnabled` to reflect the real outcome.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                // register() throws if the item is already registered, so only
                // call it when we're not already enabled.
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("dab: login item \(enabled ? "register" : "unregister") failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Turn the login item on once — the first time a build carrying this flag
    /// runs — so "start dab at login" takes effect without forcing the user into
    /// Settings. After that the Settings toggle is authoritative: this never runs
    /// again, so disabling it stays disabled.
    static func applyDefaultIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didApplyDefaultKey) else { return }
        defaults.set(true, forKey: didApplyDefaultKey)
        setEnabled(true)
    }
}
