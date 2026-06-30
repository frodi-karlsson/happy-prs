import Foundation

@testable import HappyPRs

/// In-memory `PRFetcherProtocol` for tests of code that consumes a fetcher.
final class FakePRFetcher: PRFetcherProtocol, @unchecked Sendable {
  var result: Result<[PullRequest], Error> = .success([])
  private(set) var lastTeams: [TeamRef] = []
  private(set) var lastBatchSize: Int = 0
  private(set) var fetchCount: Int = 0

  func fetch(teams: [TeamRef], detailBatchSize: Int) async throws -> [PullRequest] {
    fetchCount += 1
    lastTeams = teams
    lastBatchSize = detailBatchSize
    return try result.get()
  }
}
