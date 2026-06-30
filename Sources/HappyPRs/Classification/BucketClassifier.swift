import Foundation

public enum BucketClassifier {
  public static func classify(
    pr: PullRequest,
    me: String,
    myTeams: [TeamRef]
  ) -> BucketAssignment {
    guard pr.state == .open else { return .dropped }
    guard !pr.isDraft else { return .dropped }
    guard pr.authorLogin != me else { return .dropped }

    let myTeamSet = Set(myTeams)
    let currentlyRequestedTeamSet = Set(pr.currentlyRequestedTeams)
    let everRequestedTeamSet = Set(pr.everRequestedTeams)

    let stillRequested =
      pr.currentlyRequestedUsers.contains(me)
      || !myTeamSet.intersection(currentlyRequestedTeamSet).isEmpty

    let wasEverRequested =
      pr.everRequestedUsers.contains(me)
      || !myTeamSet.intersection(everRequestedTeamSet).isEmpty

    let myReview = pr.latestReviews.first(where: { $0.authorLogin == me })
    let neverReviewed = myReview == nil
    let staleReview = myReview.map { $0.submittedAt < pr.latestCommitDate } ?? false

    let needsMyInput =
      stillRequested
      || (neverReviewed && wasEverRequested)
      || staleReview

    let otherApproved = pr.latestReviews.contains { review in
      review.authorLogin != me
        && review.state == .approved
        && review.submittedAt >= pr.latestCommitDate
    }

    let mentionsMe =
      hasMention(of: me, in: pr.bodyText)
      || pr.commentTexts.contains(where: { hasMention(of: me, in: $0) })
      || pr.reviewSummaryTexts.contains(where: { hasMention(of: me, in: $0) })
      || pr.reviewThreadCommentTexts.contains(where: { hasMention(of: me, in: $0) })

    let needsApproval = needsMyInput && !otherApproved
    let wantsApproval = needsMyInput && otherApproved

    return BucketAssignment(
      needsApproval: needsApproval,
      wantsApproval: wantsApproval,
      mentions: mentionsMe,
      staleFlag: staleReview
    )
  }

  /// Returns true when `text` contains `@login` as a full mention —
  /// i.e. not as a prefix of a longer GitHub handle. GitHub handles
  /// are `[a-zA-Z0-9-]`, so a bare substring match for `@frodi`
  /// would incorrectly match `@frodi-doe`. We require the character
  /// after the match to either be absent (end of string) or not a
  /// handle character.
  private static func hasMention(of login: String, in text: String) -> Bool {
    let token = "@\(login)"
    var searchRange = text.startIndex..<text.endIndex
    while let found = text.range(of: token, range: searchRange) {
      if found.upperBound == text.endIndex
        || !text[found.upperBound].isGitHubHandleCharacter
      {
        return true
      }
      searchRange = found.upperBound..<text.endIndex
    }
    return false
  }
}

extension Character {
  fileprivate var isGitHubHandleCharacter: Bool {
    isASCII && (isLetter || isNumber || self == "-")
  }
}
