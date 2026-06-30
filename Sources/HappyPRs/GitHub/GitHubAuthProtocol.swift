import Foundation

/// Anything that can produce a GitHub auth token and invalidate it on
/// failure. The live impl shells out to `gh auth token`; tests can
/// supply a stub.
public protocol GitHubAuthProtocol: AnyObject, Sendable {
  func token() throws -> String
  func invalidate()
}
