import Foundation

public final class TeamResolver: TeamResolverProtocol, @unchecked Sendable {
  private struct CachedTeams: Codable {
    let viewerLogin: String
    let teams: [TeamRef]
    let fetchedAt: Date
  }

  private let client: GitHubClientProtocol
  private let defaults: UserDefaults
  private let ttl: TimeInterval
  private let cacheKey = "TeamResolver.cache.v1"

  public init(
    client: GitHubClientProtocol, defaults: UserDefaults = .standard,
    ttl: TimeInterval = 24 * 3600
  ) {
    self.client = client
    self.defaults = defaults
    self.ttl = ttl
  }

  public func resolve() async throws -> TeamResolution {
    if let cached = readCache(), Date().timeIntervalSince(cached.fetchedAt) < ttl {
      return TeamResolution(viewerLogin: cached.viewerLogin, teams: cached.teams)
    }
    // Resolve viewer login first (needs no variable), then teams.
    let viewerData = try await client.graphQL(
      query: "query { viewer { login } }", variables: [:]
    ).data
    guard let root = try JSONSerialization.jsonObject(with: viewerData) as? [String: Any],
      let dataObj = root["data"] as? [String: Any],
      let v = dataObj["viewer"] as? [String: Any],
      let login = v["login"] as? String
    else { throw ResponseDecoding.DecodingError.unexpectedShape("viewer") }

    let resp = try await client.graphQL(
      query: Queries.viewerAndTeams,
      variables: ["me": login]
    )
    let decoded = try ResponseDecoding.decodeViewerAndTeams(resp.data)
    writeCache(
      CachedTeams(
        viewerLogin: decoded.viewerLogin,
        teams: decoded.teams, fetchedAt: Date()))
    return TeamResolution(viewerLogin: decoded.viewerLogin, teams: decoded.teams)
  }

  public func invalidate() {
    defaults.removeObject(forKey: cacheKey)
  }

  private func readCache() -> CachedTeams? {
    guard let data = defaults.data(forKey: cacheKey) else { return nil }
    return try? JSONDecoder().decode(CachedTeams.self, from: data)
  }
  private func writeCache(_ c: CachedTeams) {
    if let data = try? JSONEncoder().encode(c) {
      defaults.set(data, forKey: cacheKey)
    }
  }
}
