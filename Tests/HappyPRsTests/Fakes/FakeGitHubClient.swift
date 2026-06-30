import Foundation

@testable import HappyPRs

/// Dumb queue-backed `GitHubClientProtocol`. Each call to `graphQL`
/// pops the next response off `responses` in order. Tests configure the
/// queue once and let the code under test consume it.
final class FakeGitHubClient: GitHubClientProtocol, @unchecked Sendable {
  /// FIFO of responses, mutated as calls are served.
  var responses: [Result<GitHubGraphQLResponse, Error>] = []
  /// Recorded calls in order, for assertions about what was sent.
  private(set) var calls: [(query: String, variables: [String: Any])] = []

  func graphQL(query: String, variables: [String: Any]) async throws -> GitHubGraphQLResponse {
    calls.append((query: query, variables: variables))
    return try responses.removeFirst().get()
  }
}

/// Helper to build a `GitHubGraphQLResponse` whose body is a JSON literal.
func jsonResponse(_ raw: String) -> GitHubGraphQLResponse {
  GitHubGraphQLResponse(
    data: Data(raw.utf8),
    rateLimitRemaining: nil,
    rateLimitResetAt: nil
  )
}
