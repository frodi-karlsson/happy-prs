import Foundation

/// Anything that can return the current list of pull requests relevant to
/// the viewer for a given set of teams.
public protocol PRFetcherProtocol: AnyObject, Sendable {
  func fetch(teams: [TeamRef], detailBatchSize: Int) async throws -> [PullRequest]
}
