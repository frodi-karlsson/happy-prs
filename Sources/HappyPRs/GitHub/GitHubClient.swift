import Foundation

public final class GitHubClient: GitHubClientProtocol, @unchecked Sendable {
  private let endpoint = URL(string: "https://api.github.com/graphql")!
  private let session: URLSession
  private let tokenProvider: @Sendable () throws -> String

  public init(
    session: URLSession = .shared,
    tokenProvider: @escaping @Sendable () throws -> String
  ) {
    self.session = session
    self.tokenProvider = tokenProvider
  }

  public func graphQL(
    query: String,
    variables: [String: Any]
  ) async throws -> GitHubGraphQLResponse {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let token = try tokenProvider()
    request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("HappyPRs/0.1", forHTTPHeaderField: "User-Agent")

    let body: [String: Any] = ["query": query, "variables": variables]
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw GitHubClientError.malformedResponse
    }
    if !(200..<300).contains(http.statusCode) {
      let bodyString = String(data: data, encoding: .utf8) ?? ""
      throw GitHubClientError.httpError(status: http.statusCode, body: bodyString)
    }
    let remaining =
      (http.value(forHTTPHeaderField: "X-RateLimit-Remaining"))
      .flatMap(Int.init)
    let reset =
      (http.value(forHTTPHeaderField: "X-RateLimit-Reset"))
      .flatMap(Double.init)
      .map { Date(timeIntervalSince1970: $0) }
    return GitHubGraphQLResponse(
      data: data, rateLimitRemaining: remaining, rateLimitResetAt: reset)
  }
}
