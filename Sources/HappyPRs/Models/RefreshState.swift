import Foundation

/// State of the most recent refresh attempt, surfaced to the UI.
public enum RefreshState: Equatable, Sendable {
  case idle
  case refreshing
  case error(String)
  case rateLimited(resetAt: Date)
  case notAuthenticated
  case ghNotInstalled
}
