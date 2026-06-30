import Foundation
import Testing

@testable import HappyPRs

@Test("should default to 60s refresh interval")
func shouldDefaultTo60sRefresh() {
  let defaults = UserDefaults(suiteName: "SettingsTests-\(UUID().uuidString)")!
  let s = Settings(defaults: defaults)
  #expect(s.refreshIntervalSeconds == 60)
}

@Test("should clamp refresh interval to allowed values")
func shouldClampRefreshInterval() {
  let defaults = UserDefaults(suiteName: "SettingsTests-\(UUID().uuidString)")!
  let s = Settings(defaults: defaults)
  s.refreshIntervalSeconds = 7
  #expect(s.refreshIntervalSeconds == 30)
  s.refreshIntervalSeconds = 99999
  #expect(s.refreshIntervalSeconds == 900)
}

@Test("should persist and read lastSeenSnapshots")
func shouldPersistLastSeenSnapshots() {
  let defaults = UserDefaults(suiteName: "SettingsTests-\(UUID().uuidString)")!
  let s = Settings(defaults: defaults)
  s.lastSeenSnapshots = [
    "PR_a": BucketAssignment(
      needsApproval: true, wantsApproval: false, mentions: false, staleFlag: false),
    "PR_b": BucketAssignment(
      needsApproval: false, wantsApproval: false, mentions: true, staleFlag: false),
  ]
  let s2 = Settings(defaults: defaults)
  #expect(s2.lastSeenSnapshots == s.lastSeenSnapshots)
}

@Test("should default hasMigrated to false on a fresh defaults suite")
func shouldDefaultHasMigratedFalse() {
  let defaults = UserDefaults(suiteName: "SettingsTests-\(UUID().uuidString)")!
  let s = Settings(defaults: defaults)
  #expect(s.hasMigrated == false)
}
