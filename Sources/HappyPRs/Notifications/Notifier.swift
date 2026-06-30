import AppKit
import Foundation
import UserNotifications

@MainActor
public final class Notifier: NSObject, NotifierProtocol, UNUserNotificationCenterDelegate {
  public static let shared = Notifier()

  private override init() {
    super.init()
    UNUserNotificationCenter.current().delegate = self
  }

  public func requestAuthorization() {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      if let error {
        Self.log("authorization error: \(error)")
      }
      center.getNotificationSettings { settings in
        Self.log("authorization granted=\(granted) status=\(Self.describe(settings.authorizationStatus))")
      }
    }
  }

  private static func describe(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .authorized: return "authorized"
    case .provisional: return "provisional"
    case .ephemeral: return "ephemeral"
    @unknown default: return "unknown(\(status.rawValue))"
    }
  }

  private static func log(_ message: String) {
    FileHandle.standardError.write(Data("Notifier: \(message)\n".utf8))
  }

  public func notify(for items: [ClassifiedPR]) {
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
        if let error { Self.log("post error: \(error)") }
      }
    }
  }

  private static func bucketLabel(for bucket: BucketAssignment) -> String {
    if bucket.needsApproval { return "Needs your approval" }
    if bucket.wantsApproval { return "Wants your approval" }
    return "Mentions you"
  }

  // MARK: UNUserNotificationCenterDelegate
  //
  // The delegate protocol's methods are `nonisolated` — they can be called
  // on any thread by the system framework. We can't make them main-actor
  // isolated even though the rest of `Notifier` is. NSWorkspace.open is
  // safe to call off the main actor.

  public nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let urlString = response.notification.request.content.userInfo["url"] as? String,
      let url = URL(string: urlString)
    {
      NSWorkspace.shared.open(url)
    }
    completionHandler()
  }

  public nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
