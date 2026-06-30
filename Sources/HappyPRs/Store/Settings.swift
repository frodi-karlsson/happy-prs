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

  public var lastSeenPRIDs: [String] {
    didSet { defaults.set(lastSeenPRIDs, forKey: "lastSeenPRIDs") }
  }

  /// True once the first successful refresh has stored a baseline seen-set.
  /// Used to suppress notifications on the very first refresh after install,
  /// where every PR would otherwise look "new".
  public var hasInitialized: Bool {
    didSet { defaults.set(hasInitialized, forKey: "hasInitialized") }
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
    self.lastSeenPRIDs = defaults.stringArray(forKey: "lastSeenPRIDs") ?? []
    self.hasInitialized = defaults.bool(forKey: "hasInitialized")
    if let data = defaults.data(forKey: "archives"),
      let entries = try? JSONDecoder().decode([ArchiveEntry].self, from: data)
    {
      self.archives = entries
    } else {
      self.archives = []
    }
  }
}
