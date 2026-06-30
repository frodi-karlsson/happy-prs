import Foundation

public enum ReviewState: String, Sendable, Codable {
  case pending = "PENDING"
  case commented = "COMMENTED"
  case approved = "APPROVED"
  case changesRequested = "CHANGES_REQUESTED"
  case dismissed = "DISMISSED"
}

public struct Review: Sendable, Equatable {
  public let authorLogin: String
  public let state: ReviewState
  public let submittedAt: Date

  public init(authorLogin: String, state: ReviewState, submittedAt: Date) {
    self.authorLogin = authorLogin
    self.state = state
    self.submittedAt = submittedAt
  }
}
