import Foundation

public final class PRFetcher {
    private let client: GitHubClient

    public init(client: GitHubClient) {
        self.client = client
    }

    /// Runs the combined search + per-PR detail fetch. Returns deduped PRs.
    public func fetch(teams: [TeamRef], detailBatchSize: Int = 50) async throws -> [PullRequest] {
        let query = Queries.buildSearchQuery(teams: teams)
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

        var prs: [PullRequest] = []
        for chunk in ids.chunks(ofCount: detailBatchSize) {
            let resp = try await client.graphQL(
                query: Queries.prDetails,
                variables: ["ids": Array(chunk)]
            )
            prs.append(contentsOf: try ResponseDecoding.decodePRDetails(resp.data))
        }
        return prs
    }
}

private extension Array {
    func chunks(ofCount n: Int) -> [ArraySlice<Element>] {
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
