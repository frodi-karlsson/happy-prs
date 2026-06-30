import Foundation

public final class PRFetcher: PRFetcherProtocol, @unchecked Sendable {
  private let client: GitHubClientProtocol

  public init(client: GitHubClientProtocol) {
    self.client = client
  }

  /// Runs the per-filter searches + per-PR detail fetch. Returns deduped PRs.
  ///
  /// Phase 1 (search) runs every filter concurrently — different filters
  /// don't depend on each other so we don't need to wait for the slowest
  /// one before starting the next. Pagination within a single filter
  /// stays sequential because each next page needs the previous cursor.
  /// Phase 2 (details) batches IDs and runs sequentially; the wins from
  /// parallelising the search phase are where the latency lived.
  public func fetch(teams: [TeamRef], detailBatchSize: Int = 50) async throws -> [PullRequest] {
    let queries = Queries.buildSearchQueries(teams: teams)
    let client = self.client

    let allIds: [String] = try await withThrowingTaskGroup(of: [String].self) { group in
      for query in queries {
        group.addTask {
          try await Self.collectAllIds(client: client, query: query)
        }
      }
      var union: Set<String> = []
      for try await ids in group {
        union.formUnion(ids)
      }
      return Array(union)
    }

    var prs: [PullRequest] = []
    for chunk in allIds.chunks(ofCount: detailBatchSize) {
      let resp = try await client.graphQL(
        query: Queries.prDetails,
        variables: ["ids": Array(chunk)]
      )
      prs.append(contentsOf: try ResponseDecoding.decodePRDetails(resp.data))
    }
    return prs
  }

  /// Paginate through one search filter and return every PR ID it yields.
  private static func collectAllIds(
    client: GitHubClientProtocol, query: String
  ) async throws -> [String] {
    var ids: [String] = []
    var cursor: String? = nil
    repeat {
      let resp = try await client.graphQL(
        query: Queries.searchPRs,
        variables: ["query": query, "cursor": cursor ?? NSNull()]
      )
      let page = try ResponseDecoding.decodeSearchPage(resp.data)
      ids.append(contentsOf: page.ids)
      cursor = page.hasNextPage ? page.endCursor : nil
    } while cursor != nil
    return ids
  }
}

extension Array {
  fileprivate func chunks(ofCount n: Int) -> [ArraySlice<Element>] {
    guard n > 0, !isEmpty else { return isEmpty ? [] : [self[...]] }
    var result: [ArraySlice<Element>] = []
    var i = 0
    while i < count {
      let end = Swift.min(i + n, count)
      result.append(self[i..<end])
      i = end
    }
    return result
  }
}
