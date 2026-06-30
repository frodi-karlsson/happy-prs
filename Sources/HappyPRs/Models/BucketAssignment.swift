public struct BucketAssignment: Sendable, Equatable {
  public let needsApproval: Bool
  public let wantsApproval: Bool
  public let mentions: Bool
  public let staleFlag: Bool  // true when inclusion in 1/2 was driven by staleReview

  public init(needsApproval: Bool, wantsApproval: Bool, mentions: Bool, staleFlag: Bool) {
    self.needsApproval = needsApproval
    self.wantsApproval = wantsApproval
    self.mentions = mentions
    self.staleFlag = staleFlag
  }

  public static let dropped = BucketAssignment(
    needsApproval: false, wantsApproval: false, mentions: false, staleFlag: false
  )

  public var isDropped: Bool {
    !needsApproval && !wantsApproval && !mentions
  }
}
