import Foundation

/// Surface of persisted preferences consumed by `PRStore` and friends.
/// The live impl is `Settings` (UserDefaults-backed); tests use an
/// in-memory implementation.
public protocol SettingsProtocol: AnyObject, Sendable {
  var refreshIntervalSeconds: Int { get set }
  var hiddenRepos: [String] { get set }
  var lastSeenPRIDs: [String] { get set }
  var hasInitialized: Bool { get set }
  var archives: [ArchiveEntry] { get set }
}
