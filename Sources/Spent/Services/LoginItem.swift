import ServiceManagement

/// Starts Spent at login so tracking runs even when you never open the window.
enum LoginItem {
    static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static var enabled: Bool {
        available && SMAppService.mainApp.status == .enabled
    }

    /// Returns an error message, or nil on success.
    static func set(_ on: Bool) -> String? {
        guard available else { return "Launch at login works in the installed app (scripts/build-app.sh --install)." }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
