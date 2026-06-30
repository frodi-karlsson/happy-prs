import Foundation

@testable import HappyPRs

/// In-memory `GitHubAuthProtocol` for tests. Configure `tokenResult` to
/// drive both happy-path and error-path behaviour without spawning `gh`.
final class FakeTokenProvider: GitHubAuthProtocol, @unchecked Sendable {
  var tokenResult: Result<String, Error> = .success("fake-token")
  var invalidateCalls = 0

  func token() throws -> String {
    try tokenResult.get()
  }

  func invalidate() {
    invalidateCalls += 1
  }
}
