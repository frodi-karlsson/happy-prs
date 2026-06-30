import Foundation

public final class PRFetcher: PRFetcherProtocol, @unchecked Sendable {
  private let client: GitHubClientProtocol

  public init(client: GitHubClientProtocol) {
    self.client = client
  }

  /// Runs the per-filter searches + per-PR detail fetch. Returns deduped PRs.
  /// One search query is run per filter (review-requested, mentions,
  /// reviewed-by, and one per team) because GitHub search doesn't OR
  /// across qualifiers — see `Queries.buildSearchQueries`.
  public func fetch(teams: [TeamRef], detailBatchSize: Int = 50) async throws -> [PullRequest] {
    let queries = Queries.buildSearchQueries(teams: teams)
    var allIds: Set<String> = []
    for query in queries {
      var cursor: String? = nil
      repeat {
        let resp = try await client.graphQL(
          query: Queries.searchPRs,
          variables: ["query": query, "cursor": cursor ?? NSNull()]
        )
        let page = try ResponseDecoding.decodeSearchPage(resp.data)
        allIds.formUnion(page.ids)
        cursor = page.hasNextPage ? page.endCursor : nil
      } while cursor != nil
    }

    var prs: [PullRequest] = []
    let idList = Array(allIds)
    for chunk in idList.chunks(ofCount: detailBatchSize) {
      let resp = try await client.graphQL(
        query: Queries.prDetails,
        variables: ["ids": Array(chunk)]
      )
      prs.append(contentsOf: try ResponseDecoding.decodePRDetails(resp.data))
    }
    return prs
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
