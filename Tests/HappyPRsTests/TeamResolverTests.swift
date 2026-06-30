import Foundation
import Testing

@testable import HappyPRs

/// The TeamResolver caches in UserDefaults. To isolate one test from
/// another (and from the real preferences), each test gets a fresh suite.
private func freshDefaults() -> UserDefaults {
  UserDefaults(suiteName: "TeamResolverTests-\(UUID().uuidString)")!
}

private let viewerLoginResponse = """
  {"data":{"viewer":{"login":"frodi-karlsson"}}}
  """

private let viewerAndTeamsResponse = """
  {"data":{
    "viewer":{"login":"frodi-karlsson"},
    "user":{"organizations":{"nodes":[
      {"login":"naturalcycles","teams":{"nodes":[
        {"slug":"tech"},{"slug":"web"}
      ]}}
    ]}}
  }}
  """

@Test("should fetch viewer login then teams and return resolution")
func shouldFetchViewerThenTeams() async throws {
  let client = FakeGitHubClient()
  client.responses = [
    .success(jsonResponse(viewerLoginResponse)),
    .success(jsonResponse(viewerAndTeamsResponse)),
  ]
  let resolver = TeamResolver(client: client, defaults: freshDefaults(), ttl: 3600)

  let resolution = try await resolver.resolve()

  #expect(resolution.viewerLogin == "frodi-karlsson")
  #expect(
    resolution.teams == [
      TeamRef(org: "naturalcycles", slug: "tech"),
      TeamRef(org: "naturalcycles", slug: "web"),
    ])
  #expect(client.calls.count == 2)
}

@Test("should serve subsequent calls from cache while within TTL")
func shouldServeFromCacheWithinTTL() async throws {
  let client = FakeGitHubClient()
  client.responses = [
    .success(jsonResponse(viewerLoginResponse)),
    .success(jsonResponse(viewerAndTeamsResponse)),
  ]
  let resolver = TeamResolver(client: client, defaults: freshDefaults(), ttl: 3600)

  _ = try await resolver.resolve()
  _ = try await resolver.resolve()

  // Second resolve hits the cache — no additional GraphQL calls.
  #expect(client.calls.count == 2)
}

@Test("should refetch after invalidate")
func shouldRefetchAfterInvalidate() async throws {
  let client = FakeGitHubClient()
  client.responses = [
    .success(jsonResponse(viewerLoginResponse)),
    .success(jsonResponse(viewerAndTeamsResponse)),
    .success(jsonResponse(viewerLoginResponse)),
    .success(jsonResponse(viewerAndTeamsResponse)),
  ]
  let resolver = TeamResolver(client: client, defaults: freshDefaults(), ttl: 3600)

  _ = try await resolver.resolve()
  resolver.invalidate()
  _ = try await resolver.resolve()

  #expect(client.calls.count == 4)
}

@Test("should refetch when cached entry is older than TTL")
func shouldRefetchWhenCacheStale() async throws {
  let client = FakeGitHubClient()
  client.responses = [
    .success(jsonResponse(viewerLoginResponse)),
    .success(jsonResponse(viewerAndTeamsResponse)),
    .success(jsonResponse(viewerLoginResponse)),
    .success(jsonResponse(viewerAndTeamsResponse)),
  ]
  // Tiny TTL: by the time we sleep 50ms, the cache is stale.
  let resolver = TeamResolver(client: client, defaults: freshDefaults(), ttl: 0.01)

  _ = try await resolver.resolve()
  try await Task.sleep(for: .milliseconds(50))
  _ = try await resolver.resolve()

  #expect(client.calls.count == 4)
}
