import Foundation

/// Intercepts URLSession requests when configured into the session.
/// Tests set `requestHandler` to provide canned responses.
///
/// Cross-suite exclusion: call `MockURLProtocol.acquire()` at the start of
/// any test that sets `requestHandler`, and `MockURLProtocol.release()` in
/// a `defer` block. This prevents two concurrently-running suites from
/// clobbering each other's handler.
final class MockURLProtocol: URLProtocol {
  nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  /// Binary semaphore — only one test at a time may own the mock handler.
  private static let semaphore = DispatchSemaphore(value: 1)

  /// Acquire exclusive mock ownership. Call at test start.
  static func acquire() { semaphore.wait() }
  /// Release mock ownership. Call in defer at test start.
  static func release() { semaphore.signal() }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = MockURLProtocol.requestHandler else {
      client?.urlProtocol(
        self,
        didFailWithError:
          NSError(domain: "MockURLProtocol", code: -1))
      return
    }
    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}

  /// Builds a session that routes through MockURLProtocol.
  static func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
  }
}
