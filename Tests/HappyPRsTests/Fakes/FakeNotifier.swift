import Foundation

@testable import HappyPRs

/// In-memory `NotifierProtocol` for tests. Records every batch passed to
/// `notify(for:)` so assertions can inspect what would have been posted.
final class FakeNotifier: NotifierProtocol, @unchecked Sendable {
  private(set) var notifiedBatches: [[ClassifiedPR]] = []
  private(set) var authorizationRequestCount: Int = 0

  func notify(for items: [ClassifiedPR]) async {
    notifiedBatches.append(items)
  }

  func requestAuthorization() async {
    authorizationRequestCount += 1
  }
}
