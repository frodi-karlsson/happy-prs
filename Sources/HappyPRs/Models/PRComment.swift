import Foundation

/// A single comment or review-body message on a pull request, with
/// enough metadata for the classifier to answer "who wrote this and
/// when" — needed to detect "I commented, someone replied" cases that
/// the review-state signals alone can't cover.
public struct PRComment: Sendable, Equatable, Codable {
  public let authorLogin: String
  public let createdAt: Date
  public let bodyText: String

  public init(authorLogin: String, createdAt: Date, bodyText: String) {
    self.authorLogin = authorLogin
    self.createdAt = createdAt
    self.bodyText = bodyText
  }
}
