import Foundation

/// Errors thrown by anything that resolves a GitHub auth token.
public enum GitHubAuthError: Error, Equatable, Sendable {
  case notInstalled
  case notAuthenticated
}
