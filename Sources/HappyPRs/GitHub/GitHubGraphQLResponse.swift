import Foundation

/// Wire-level result of a GraphQL POST against GitHub.
public struct GitHubGraphQLResponse: Sendable {
  public let data: Data
  public let rateLimitRemaining: Int?
  public let rateLimitResetAt: Date?

  public init(data: Data, rateLimitRemaining: Int?, rateLimitResetAt: Date?) {
    self.data = data
    self.rateLimitRemaining = rateLimitRemaining
    self.rateLimitResetAt = rateLimitResetAt
  }
}
