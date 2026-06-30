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

@Test("should persist and read lastSeenPRIDs")
func shouldPersistLastSeenIDs() {
  let defaults = UserDefaults(suiteName: "SettingsTests-\(UUID().uuidString)")!
  let s = Settings(defaults: defaults)
  s.lastSeenPRIDs = ["PR_a", "PR_b"]
  let s2 = Settings(defaults: defaults)
  #expect(s2.lastSeenPRIDs == ["PR_a", "PR_b"])
}
