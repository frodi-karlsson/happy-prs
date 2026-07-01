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

    let awaitingResponse = detectAwaitingResponse(pr: pr, me: me)

    let needsMyInput =
      stillRequested
      || (neverReviewed && wasEverRequested)
      || staleReview
      || awaitingResponse

    let otherApproved = pr.latestReviews.contains { review in
      review.authorLogin != me
        && review.state == .approved
        && review.submittedAt >= pr.latestCommitDate
    }

    let mentionsMe =
      hasMention(of: me, in: pr.bodyText)
      || pr.comments.contains(where: { hasMention(of: me, in: $0.bodyText) })
      || pr.reviewSummaries.contains(where: { hasMention(of: me, in: $0.bodyText) })
      || pr.reviewThreadComments.contains(where: { hasMention(of: me, in: $0.bodyText) })

    let needsApproval = needsMyInput && !otherApproved
    let wantsApproval = needsMyInput && otherApproved

    return BucketAssignment(
      needsApproval: needsApproval,
      wantsApproval: wantsApproval,
      mentions: mentionsMe,
      staleFlag: staleReview
    )
  }

  /// Returns true when I have activity on this PR that isn't an approval
  /// AND someone else has activity strictly after my latest such
  /// activity — i.e. I asked (or requested changes, or just chimed in)
  /// and they've since replied. Approvals are excluded from "my
  /// activity" because once I've approved, follow-up conversation
  /// shouldn't drag the PR back into my buckets.
  private static func detectAwaitingResponse(pr: PullRequest, me: String) -> Bool {
    var myLatest: Date? = nil
    var othersLatest: Date? = nil

    // Reviews contribute to activity, but only my non-approval ones.
    for review in pr.latestReviews {
      if review.authorLogin == me {
        if review.state != .approved {
          myLatest = max(myLatest ?? .distantPast, review.submittedAt)
        }
      } else {
        othersLatest = max(othersLatest ?? .distantPast, review.submittedAt)
      }
    }

    // All comment kinds count. `bodyText` on comments is checked in the
    // mentions logic — here we only need the timestamp + author.
    for source in [pr.comments, pr.reviewSummaries, pr.reviewThreadComments] {
      for comment in source {
        if comment.authorLogin == me {
          myLatest = max(myLatest ?? .distantPast, comment.createdAt)
        } else {
          othersLatest = max(othersLatest ?? .distantPast, comment.createdAt)
        }
      }
    }

    guard let mine = myLatest, let theirs = othersLatest else { return false }
    return theirs > mine
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
