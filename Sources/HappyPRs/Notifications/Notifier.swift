import AppKit
import Foundation
import UserNotifications

@MainActor
public final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = Notifier()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error { print("Notifier authorization error: \(error)") }
        }
    }

    public func notify(for items: [PRStore.ClassifiedPR]) {
        let center = UNUserNotificationCenter.current()
        for item in items {
            let content = UNMutableNotificationContent()
            content.title = "\(item.pr.repo) #\(item.pr.number) — \(Self.bucketLabel(for: item.bucket))"
            content.body = "\(item.pr.title) — \(item.pr.authorLogin)"
            content.userInfo = ["url": item.pr.url.absoluteString]
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "happyprs.\(item.id)",
                content: content,
                trigger: nil
            )
            center.add(request) { error in
                if let error { print("Notifier post error: \(error)") }
            }
        }
    }

    private static func bucketLabel(for bucket: BucketAssignment) -> String {
        if bucket.needsApproval { return "Needs your approval" }
        if bucket.wantsApproval { return "Wants your approval" }
        return "Mentions you"
    }

    // MARK: UNUserNotificationCenterDelegate

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        completionHandler()
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
