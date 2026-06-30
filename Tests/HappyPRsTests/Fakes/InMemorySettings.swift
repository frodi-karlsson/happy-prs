import Foundation

@testable import HappyPRs

/// In-memory `SettingsProtocol` for tests. Stores every value in plain
/// fields — no clamping, no UserDefaults round-trip. Use this when the
/// test wants to assert what was written by inspecting the field directly.
final class InMemorySettings: SettingsProtocol, @unchecked Sendable {
  var refreshIntervalSeconds: Int = 60
  var hiddenRepos: [String] = []
  var lastSeenSnapshots: [String: BucketAssignment] = [:]
  var hasInitialized: Bool = false
  var hasMigrated: Bool = false
  var archives: [ArchiveEntry] = []
}
