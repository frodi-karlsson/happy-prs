import Testing
import Foundation
@testable import HappyPRs

private func readBodyData(_ req: URLRequest) -> Data {
    if let d = req.httpBody { return d }
    guard let stream = req.httpBodyStream else { return Data() }
    stream.open(); defer { stream.close() }
    var data = Data()
    let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
    defer { buf.deallocate() }
    while stream.hasBytesAvailable {
        let n = stream.read(buf, maxLength: 4096)
        if n <= 0 { break }
        data.append(buf, count: n)
    }
    return data
}

@Suite(.serialized) struct PRFetcherTests {
    @Test("should fetch search page then PR details via two GraphQL calls")
    func shouldFetchSearchThenDetails() async throws {
        let calls = Counter()
        MockURLProtocol.acquire(); defer { MockURLProtocol.requestHandler = nil; MockURLProtocol.release() }
        MockURLProtocol.requestHandler = { req in
            calls.value += 1
            let body = String(data: readBodyData(req), encoding: .utf8) ?? ""
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
            if body.contains("query Search") {
                let url = Bundle.module.url(forResource: "search-sample", withExtension: "json",
                                            subdirectory: "Fixtures")!
                return (resp, try Data(contentsOf: url))
            } else {
                let url = Bundle.module.url(forResource: "pr-detail-sample", withExtension: "json",
                                            subdirectory: "Fixtures")!
                return (resp, try Data(contentsOf: url))
            }
        }
        let client = GitHubClient(session: MockURLProtocol.makeSession(),
                                  tokenProvider: { "t" })
        let fetcher = PRFetcher(client: client)
        let prs = try await fetcher.fetch(teams: [], detailBatchSize: 50)
        #expect(prs.count == 1)
        #expect(prs[0].number == 42)
        #expect(calls.value == 2)
    }
}

final class Counter: @unchecked Sendable {
    var value = 0
}
