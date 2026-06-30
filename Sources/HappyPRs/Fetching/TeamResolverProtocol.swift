import Foundation

/// Anything that resolves the viewer's login plus their team memberships.
public protocol TeamResolverProtocol: AnyObject, Sendable {
  func resolve() async throws -> TeamResolution
  func invalidate()
}
