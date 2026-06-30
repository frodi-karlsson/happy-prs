import Foundation

/// Anything that can post user-visible notifications for newly-arrived PRs
/// and ask the system for permission. Async-everywhere so the live impl
/// (which is `@MainActor`) can satisfy the requirement, and so test fakes
/// can stay simple.
public protocol NotifierProtocol: Sendable {
  func notify(for items: [ClassifiedPR]) async
  func requestAuthorization() async
}
