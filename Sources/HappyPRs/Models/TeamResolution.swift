import Foundation

/// Result of resolving the viewer's login plus their team memberships.
public struct TeamResolution: Equatable, Sendable {
  public let viewerLogin: String
  public let teams: [TeamRef]

  public init(viewerLogin: String, teams: [TeamRef]) {
    self.viewerLogin = viewerLogin
    self.teams = teams
  }
}
