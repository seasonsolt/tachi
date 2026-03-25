import AppKit
import Foundation
import UserNotifications

final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()

    private let threshold = 80
    private var notifiedAccountIds: Set<Int> = []

    func requestAuthorization() {
        guard canUseUserNotifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(items: [AccountWithUsage]) {
        guard canUseUserNotifications else { return }
        for item in items {
            let util = item.maxUtilization
            if util >= threshold && !notifiedAccountIds.contains(item.id) {
                notifiedAccountIds.insert(item.id)
                sendNotification(account: item.account, utilization: util)
            } else if util < threshold {
                notifiedAccountIds.remove(item.id)
            }
        }
    }

    private func sendNotification(account: Account, utilization: Int) {
        let content = UNMutableNotificationContent()
        content.title = "High Usage Alert"
        content.body = "\(account.name) is at \(utilization)% utilization"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "high-usage-\(account.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    @MainActor
    func playTaskCompletionCue() {
        let preferredNames = ["Glass", "Hero", "Ping"]
        for name in preferredNames {
            if let sound = NSSound(named: NSSound.Name(name)) {
                sound.play()
                return
            }
        }
        NSSound.beep()
    }

    private var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }
}
