import Foundation

@testable import HappyPRs

/// In-memory `TeamResolverProtocol` for tests of code that consumes a
/// resolver.
final class FakeTeamResolver: TeamResolverProtocol, @unchecked Sendable {
  var resolveResult: Result<TeamResolution, Error> = .success(
    TeamResolution(viewerLogin: "me", teams: []))
  private(set) var resolveCount: Int = 0
  private(set) var invalidateCount: Int = 0

  func resolve() async throws -> TeamResolution {
    resolveCount += 1
    return try resolveResult.get()
  }

  func invalidate() {
    invalidateCount += 1
  }
}
