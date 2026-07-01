import Foundation

public enum PRState: String, Sendable, Codable {
  case open
  case closed
  case merged
}

public struct PullRequest: Sendable, Equatable {
  public let id: String
  public let repo: String  // "owner/name"
  public let number: Int
  public let title: String
  public let url: URL
  public let authorLogin: String
  public let state: PRState
  public let isDraft: Bool
  public let latestCommitDate: Date

  public let currentlyRequestedUsers: [String]  // logins
  public let currentlyRequestedTeams: [TeamRef]

  public let everRequestedUsers: [String]
  public let everRequestedTeams: [TeamRef]

  public let latestReviews: [Review]  // one per author (GH `latestReviews`)

  public let bodyText: String
  /// Top-level issue comments on the PR.
  public let comments: [PRComment]
  /// Reviews' free-text summary bodies (not the inline thread comments).
  public let reviewSummaries: [PRComment]
  /// Comments inside review discussion threads (inline code comments and
  /// their replies).
  public let reviewThreadComments: [PRComment]

  public init(
    id: String, repo: String, number: Int, title: String, url: URL,
    authorLogin: String, state: PRState, isDraft: Bool,
    latestCommitDate: Date,
    currentlyRequestedUsers: [String], currentlyRequestedTeams: [TeamRef],
    everRequestedUsers: [String], everRequestedTeams: [TeamRef],
    latestReviews: [Review],
    bodyText: String,
    comments: [PRComment],
    reviewSummaries: [PRComment],
    reviewThreadComments: [PRComment]
  ) {
    self.id = id; self.repo = repo; self.number = number; self.title = title
    self.url = url; self.authorLogin = authorLogin; self.state = state
    self.isDraft = isDraft; self.latestCommitDate = latestCommitDate
    self.currentlyRequestedUsers = currentlyRequestedUsers
    self.currentlyRequestedTeams = currentlyRequestedTeams
    self.everRequestedUsers = everRequestedUsers
    self.everRequestedTeams = everRequestedTeams
    self.latestReviews = latestReviews
    self.bodyText = bodyText
    self.comments = comments
    self.reviewSummaries = reviewSummaries
    self.reviewThreadComments = reviewThreadComments
  }
}
