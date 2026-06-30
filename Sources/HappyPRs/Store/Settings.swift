import Foundation
import Observation

@Observable
public final class Settings: SettingsProtocol, @unchecked Sendable {
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private static let allowedIntervals: [Int] = [30, 60, 120, 300, 900]

  public var refreshIntervalSeconds: Int {
    didSet {
      let clamped =
        Self.allowedIntervals.min(by: {
          abs($0 - refreshIntervalSeconds) < abs($1 - refreshIntervalSeconds)
        }) ?? 60
      if clamped != refreshIntervalSeconds {
        // Recursion guard: only re-assign if it changes the value.
        refreshIntervalSeconds = clamped
        return
      }
      defaults.set(refreshIntervalSeconds, forKey: "refreshIntervalSeconds")
    }
  }

  public var hiddenRepos: [String] {
    didSet { defaults.set(hiddenRepos, forKey: "hiddenRepos") }
  }

  public var lastSeenSnapshots: [String: BucketAssignment] {
    didSet {
      if let data = try? JSONEncoder().encode(lastSeenSnapshots) {
        defaults.set(data, forKey: "lastSeenSnapshots")
      }
    }
  }

  /// True once the first successful refresh has stored a baseline seen-set.
  /// Used to suppress notifications on the very first refresh after install,
  /// where every PR would otherwise look "new".
  public var hasInitialized: Bool {
    didSet { defaults.set(hasInitialized, forKey: "hasInitialized") }
  }

  /// True after the first refresh under the snapshot-based notification
  /// model. Combined with `hasInitialized` to suppress the one-time flood
  /// when an upgrading user goes from ID-only seen-sets to bucket snapshots.
  public var hasMigrated: Bool {
    didSet { defaults.set(hasMigrated, forKey: "hasMigrated") }
  }

  public var archives: [ArchiveEntry] {
    didSet {
      if let data = try? JSONEncoder().encode(archives) {
        defaults.set(data, forKey: "archives")
      }
    }
  }

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.refreshIntervalSeconds = defaults.object(forKey: "refreshIntervalSeconds") as? Int ?? 60
    self.hiddenRepos = defaults.stringArray(forKey: "hiddenRepos") ?? []
    self.hasInitialized = defaults.bool(forKey: "hasInitialized")
    self.hasMigrated = defaults.bool(forKey: "hasMigrated")
    if let data = defaults.data(forKey: "lastSeenSnapshots"),
      let decoded = try? JSONDecoder().decode([String: BucketAssignment].self, from: data)
    {
      self.lastSeenSnapshots = decoded
    } else {
      self.lastSeenSnapshots = [:]
    }
    if let data = defaults.data(forKey: "archives"),
      let entries = try? JSONDecoder().decode([ArchiveEntry].self, from: data)
    {
      self.archives = entries
    } else {
      self.archives = []
    }
  }
}
