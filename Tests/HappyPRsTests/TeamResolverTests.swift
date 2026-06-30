import Testing
import Foundation
@testable import HappyPRs

@Suite(.serialized) struct TeamResolverTests {
    @Test("should fetch teams and cache them, returning cached value within TTL")
    func shouldFetchAndCacheTeams() async throws {
        MockURLProtocol.acquire(); defer { MockURLProtocol.requestHandler = nil; MockURLProtocol.release() }
        let calls = Counter()
        MockURLProtocol.requestHandler = { req in
            calls.value += 1
            let url = Bundle.module.url(forResource: "viewer-teams-sample",
                                        withExtension: "json", subdirectory: "Fixtures")!
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
            return (resp, try Data(contentsOf: url))
        }
        let client = GitHubClient(session: MockURLProtocol.makeSession(),
                                  tokenProvider: { "t" })
        let defaults = UserDefaults(suiteName: "TeamResolverTests-\(UUID().uuidString)")!
        let resolver = TeamResolver(client: client, defaults: defaults, ttl: 60)

        let first = try await resolver.resolve()
        #expect(first.viewerLogin == "frodi-karlsson")
        #expect(first.teams.count == 2)
        #expect(calls.value == 2)  // first resolve: viewer query + viewerAndTeams query = 2 calls

        let second = try await resolver.resolve()
        #expect(second.teams == first.teams)
        #expect(calls.value == 2, "should not refetch within TTL")
    }
}
