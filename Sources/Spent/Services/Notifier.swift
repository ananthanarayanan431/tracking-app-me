import Foundation
import UserNotifications

/// Mac notifications for limits, reminders and focus sessions. Only works inside the
/// bundled .app (UNUserNotificationCenter needs a bundle identifier); under `swift run`
/// callers fall back to in-app toasts.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    private(set) var allowed = false
    private(set) var status: UNAuthorizationStatus = .notDetermined

    var available: Bool { Bundle.main.bundleIdentifier != nil }

    private var center: UNUserNotificationCenter? {
        available ? UNUserNotificationCenter.current() : nil
    }

    func setUp() {
        center?.delegate = self
    }

    func refreshState() async {
        guard let center else { return }
        let s = await center.notificationSettings()
        status = s.authorizationStatus
        allowed = status == .authorized || status == .provisional
    }

    func requestPermission() async -> Bool {
        guard let center else { return false }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        await refreshState()
        return allowed
    }

    func post(_ body: String) {
        guard let center, allowed else { return }
        let content = UNMutableNotificationContent()
        content.title = "Spent"
        content.body = String(body.prefix(300))
        content.sound = .default
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // Show banners even while Spent is the active app.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
