import Foundation
import Testing

@testable import HappyPRs

private func searchPageJSON(ids: [String], hasNextPage: Bool = false, endCursor: String? = nil)
  -> String
{
  let nodes = ids.map { "{\"id\": \"\($0)\"}" }.joined(separator: ",")
  let cursor = endCursor.map { "\"\($0)\"" } ?? "null"
  return """
    {"data":{"search":{
      "pageInfo": {"endCursor": \(cursor), "hasNextPage": \(hasNextPage)},
      "nodes": [\(nodes)]
    }}}
    """
}

private func detailsJSON(ids: [String]) -> String {
  let nodes = ids.enumerated().map { i, id in
    """
    {
      "id": "\(id)",
      "number": \(i + 1),
      "url": "https://example.com/pr/\(i + 1)",
      "title": "t\(i + 1)",
      "isDraft": false,
      "state": "OPEN",
      "author": {"login": "alice"},
      "repository": {"nameWithOwner": "org/repo"}
    }
    """
  }.joined(separator: ",")
  return "{\"data\":{\"nodes\":[\(nodes)]}}"
}

@Test("should run one search per filter, dedupe IDs, then fetch details once")
func shouldRunOneSearchPerFilter_andDedupe() async throws {
  let client = FakeGitHubClient()
  // 3 base filters (no teams); each returns the same two IDs to force dedup.
  client.responses = [
    .success(jsonResponse(searchPageJSON(ids: ["PR_a", "PR_b"]))),
    .success(jsonResponse(searchPageJSON(ids: ["PR_a", "PR_b"]))),
    .success(jsonResponse(searchPageJSON(ids: ["PR_a", "PR_b"]))),
    .success(jsonResponse(detailsJSON(ids: ["PR_a", "PR_b"]))),
  ]
  let fetcher = PRFetcher(client: client)

  let prs = try await fetcher.fetch(teams: [], detailBatchSize: 50)

  #expect(prs.count == 2)
  #expect(client.calls.count == 4)
}

@Test("should follow pagination cursor across multiple search pages")
func shouldFollowPaginationCursor() async throws {
  let client = FakeGitHubClient()
  // First filter (review-requested) returns two pages.
  // Remaining two filters return one page each, no overlap.
  client.responses = [
    .success(
      jsonResponse(searchPageJSON(ids: ["PR_a"], hasNextPage: true, endCursor: "cur1"))),
    .success(jsonResponse(searchPageJSON(ids: ["PR_b"]))),
    .success(jsonResponse(searchPageJSON(ids: ["PR_c"]))),
    .success(jsonResponse(searchPageJSON(ids: ["PR_d"]))),
    .success(jsonResponse(detailsJSON(ids: ["PR_a", "PR_b", "PR_c", "PR_d"]))),
  ]
  let fetcher = PRFetcher(client: client)

  let prs = try await fetcher.fetch(teams: [], detailBatchSize: 50)

  #expect(prs.count == 4)
  // 2 search calls for first filter (paginated) + 1 each for the other two
  // + 1 detail batch = 5 calls.
  #expect(client.calls.count == 5)
  // The second call must carry the cursor we returned.
  let secondCallVars = client.calls[1].variables
  #expect((secondCallVars["cursor"] as? String) == "cur1")
}

@Test("should chunk detail fetch by detailBatchSize")
func shouldChunkDetailFetch() async throws {
  let client = FakeGitHubClient()
  // 3 search calls return non-overlapping IDs so we end up with 5 unique.
  client.responses = [
    .success(jsonResponse(searchPageJSON(ids: ["PR_1", "PR_2"]))),
    .success(jsonResponse(searchPageJSON(ids: ["PR_3", "PR_4"]))),
    .success(jsonResponse(searchPageJSON(ids: ["PR_5"]))),
    // detailBatchSize = 2 → 3 batches: [2, 2, 1]
    .success(jsonResponse(detailsJSON(ids: ["PR_1", "PR_2"]))),
    .success(jsonResponse(detailsJSON(ids: ["PR_3", "PR_4"]))),
    .success(jsonResponse(detailsJSON(ids: ["PR_5"]))),
  ]
  let fetcher = PRFetcher(client: client)

  let prs = try await fetcher.fetch(teams: [], detailBatchSize: 2)

  #expect(prs.count == 5)
  // 3 searches + 3 detail batches = 6 calls
  #expect(client.calls.count == 6)
}

@Test("should include one search per team in addition to the base filters")
func shouldIncludeOneSearchPerTeam() async throws {
  let client = FakeGitHubClient()
  // 3 base + 2 team = 5 search calls, then one (empty) detail batch.
  for _ in 0..<5 {
    client.responses.append(.success(jsonResponse(searchPageJSON(ids: []))))
  }
  // With zero IDs, PRFetcher skips the detail call entirely.
  let fetcher = PRFetcher(client: client)

  _ = try await fetcher.fetch(
    teams: [
      TeamRef(org: "naturalcycles", slug: "tech"),
      TeamRef(org: "naturalcycles", slug: "web"),
    ], detailBatchSize: 50)

  #expect(client.calls.count == 5)
}
