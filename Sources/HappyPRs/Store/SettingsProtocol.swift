import Foundation

/// Surface of persisted preferences consumed by `PRStore` and friends.
/// The live impl is `Settings` (UserDefaults-backed); tests use an
/// in-memory implementation.
public protocol SettingsProtocol: AnyObject, Sendable {
  var refreshIntervalSeconds: Int { get set }
  var hiddenRepos: [String] { get set }
  /// Bucket state we last showed the user for each active PR, keyed by
  /// PR node ID. Used to detect transitions (e.g. a PR newly going
  /// stale, or a PR newly entering an actionable bucket) so the
  /// notifier can fire on more than just first-time PRs.
  var lastSeenSnapshots: [String: BucketAssignment] { get set }
  var hasInitialized: Bool { get set }
  /// One-shot flag set the first time `PRStore.refresh` runs under the
  /// snapshot-based notification model. Used to suppress notifications
  /// the once when a user upgrades from the older ID-based seen-set.
  var hasMigrated: Bool { get set }
  var archives: [ArchiveEntry] { get set }
}
