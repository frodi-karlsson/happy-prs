import Foundation

/// Anything that can POST a GraphQL query to GitHub and return raw JSON.
public protocol GitHubClientProtocol: AnyObject, Sendable {
  func graphQL(query: String, variables: [String: Any]) async throws -> GitHubGraphQLResponse
}
