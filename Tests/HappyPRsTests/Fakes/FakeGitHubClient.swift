import Foundation

@testable import HappyPRs

/// Dumb queue-backed `GitHubClientProtocol`. Each call to `graphQL`
/// pops the next response off `responses` in order. Concurrent callers
/// (e.g. PRFetcher's phase-1 TaskGroup) are serialized through a lock
/// so the queue pops atomically — no smart routing on input, the
/// order responses are configured is the order they're served.
final class FakeGitHubClient: GitHubClientProtocol, @unchecked Sendable {
  private let lock = NSLock()
  private var _responses: [Result<GitHubGraphQLResponse, Error>] = []
  private var _calls: [(query: String, variables: [String: Any])] = []

  var responses: [Result<GitHubGraphQLResponse, Error>] {
    get { lock.withLock { _responses } }
    set { lock.withLock { _responses = newValue } }
  }

  var calls: [(query: String, variables: [String: Any])] {
    lock.withLock { _calls }
  }

  func graphQL(query: String, variables: [String: Any]) async throws -> GitHubGraphQLResponse {
    let response: Result<GitHubGraphQLResponse, Error> = lock.withLock {
      _calls.append((query: query, variables: variables))
      return _responses.removeFirst()
    }
    return try response.get()
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
