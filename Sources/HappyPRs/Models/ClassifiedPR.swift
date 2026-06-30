import Foundation

/// A `PullRequest` that has been classified into one or more buckets,
/// annotated with whether it's new since the last seen-set.
public struct ClassifiedPR: Identifiable, Equatable, Sendable {
  public let pr: PullRequest
  public let bucket: BucketAssignment
  public let isNew: Bool
  public var id: String { pr.id }

  public init(pr: PullRequest, bucket: BucketAssignment, isNew: Bool) {
    self.pr = pr
    self.bucket = bucket
    self.isNew = isNew
  }
}
