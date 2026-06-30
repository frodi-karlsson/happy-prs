import Foundation

/// Errors thrown by anything that runs GraphQL against GitHub.
public enum GitHubClientError: Error, Equatable, Sendable {
  case httpError(status: Int, body: String)
  case malformedResponse
}
