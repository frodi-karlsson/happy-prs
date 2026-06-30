import Testing
import Foundation
@testable import HappyPRs

private func readAll(_ stream: InputStream) -> Data {
    stream.open(); defer { stream.close() }
    var data = Data()
    let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
    defer { buf.deallocate() }
    while stream.hasBytesAvailable {
        let read = stream.read(buf, maxLength: 4096)
        if read <= 0 { break }
        data.append(buf, count: read)
    }
    return data
}

@Suite(.serialized)
struct GitHubClientTests {

@Test("should POST a GraphQL query with bearer token and return body data")
func shouldPostGraphQLQuery_andReturnBody() async throws {
    MockURLProtocol.requestHandler = { req in
        #expect(req.url == URL(string: "https://api.github.com/graphql"))
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "bearer test-token")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = req.httpBody ?? req.httpBodyStream.map(readAll) ?? Data()
        #expect(String(data: body, encoding: .utf8)?.contains("\"query\"") == true)
        let resp = HTTPURLResponse(url: req.url!, statusCode: 200,
                                   httpVersion: nil,
                                   headerFields: ["X-RateLimit-Remaining": "4999"])!
        return (resp, Data("{\"data\":{}}".utf8))
    }

    let client = GitHubClient(
        session: MockURLProtocol.makeSession(),
        tokenProvider: { "test-token" }
    )
    let result = try await client.graphQL(query: "{ viewer { login } }", variables: [:])
    #expect(String(data: result.data, encoding: .utf8) == "{\"data\":{}}")
    #expect(result.rateLimitRemaining == 4999)
}

@Test("should throw httpError on non-2xx status")
func shouldThrowHTTPError_onNon2xx() async {
    MockURLProtocol.requestHandler = { req in
        let resp = HTTPURLResponse(url: req.url!, statusCode: 401,
                                   httpVersion: nil, headerFields: nil)!
        return (resp, Data("{\"message\":\"Bad credentials\"}".utf8))
    }
    let client = GitHubClient(
        session: MockURLProtocol.makeSession(),
        tokenProvider: { "test-token" }
    )
    await #expect(throws: GitHubClient.ClientError.self) {
        _ = try await client.graphQL(query: "x", variables: [:])
    }
}

} // GitHubClientTests
