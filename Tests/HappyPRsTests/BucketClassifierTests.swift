import Foundation
import Testing

@testable import HappyPRs

private let me = "frodi-karlsson"
private let myTeams: [TeamRef] = [TeamRef(org: "naturalcycles", slug: "backend")]

/// Convenience: wrap raw text in a PRComment authored by an anonymous
/// "someone" (i.e. not `me`) at the same fixed date used by defaults.
/// Tests that don't care about author/time can pass strings.
private func anon(_ text: String, at date: Date = Date(timeIntervalSince1970: 1_000_000))
  -> PRComment
{
  PRComment(authorLogin: "someone", createdAt: date, bodyText: text)
}

private func makePR(
  state: PRState = .open,
  isDraft: Bool = false,
  authorLogin: String = "alice",
  latestCommitDate: Date = Date(timeIntervalSince1970: 1_000_000),
  currentlyRequestedUsers: [String] = [],
  currentlyRequestedTeams: [TeamRef] = [],
  everRequestedUsers: [String] = [],
  everRequestedTeams: [TeamRef] = [],
  latestReviews: [Review] = [],
  bodyText: String = "",
  commentTexts: [String] = [],
  reviewSummaryTexts: [String] = [],
  reviewThreadCommentTexts: [String] = [],
  comments: [PRComment] = [],
  reviewSummaries: [PRComment] = [],
  reviewThreadComments: [PRComment] = []
) -> PullRequest {
  PullRequest(
    id: "PR_x", repo: "org/repo", number: 1,
    title: "test", url: URL(string: "https://example.com")!,
    authorLogin: authorLogin, state: state, isDraft: isDraft,
    latestCommitDate: latestCommitDate,
    currentlyRequestedUsers: currentlyRequestedUsers,
    currentlyRequestedTeams: currentlyRequestedTeams,
    everRequestedUsers: everRequestedUsers,
    everRequestedTeams: everRequestedTeams,
    latestReviews: latestReviews,
    bodyText: bodyText,
    comments: comments + commentTexts.map { anon($0) },
    reviewSummaries: reviewSummaries + reviewSummaryTexts.map { anon($0) },
    reviewThreadComments: reviewThreadComments + reviewThreadCommentTexts.map { anon($0) }
  )
}

@Test("should classify as needs-approval when never reviewed and currently requested")
func shouldClassifyNeedsApproval_whenNeverReviewedAndRequested() {
  let pr = makePR(currentlyRequestedUsers: [me], everRequestedUsers: [me])
  let result = BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams)
  #expect(result.needsApproval)
  #expect(!result.wantsApproval)
  #expect(!result.mentions)
  #expect(!result.staleFlag)
}

@Test("should drop when I approved and there are no newer commits")
func shouldDrop_whenIApprovedAndNoNewCommits() {
  let commitDate = Date(timeIntervalSince1970: 1_000_000)
  let myReview = Review(
    authorLogin: me, state: .approved,
    submittedAt: commitDate.addingTimeInterval(60))
  let pr = makePR(
    latestCommitDate: commitDate,
    everRequestedUsers: [me],
    latestReviews: [myReview]
  )
  #expect(BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams).isDropped)
}

@Test("should classify as needs-approval (stale) when I approved but new commits landed")
func shouldClassifyStaleNeedsApproval_whenApprovalIsStale() {
  let oldReviewDate = Date(timeIntervalSince1970: 1_000_000)
  let newCommitDate = oldReviewDate.addingTimeInterval(3600)
  let myReview = Review(authorLogin: me, state: .approved, submittedAt: oldReviewDate)
  let pr = makePR(
    latestCommitDate: newCommitDate,
    everRequestedUsers: [me],
    latestReviews: [myReview]
  )
  let result = BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams)
  #expect(result.needsApproval)
  #expect(result.staleFlag)
}

@Test("should classify as wants-approval when my approval is stale but someone else just approved")
func shouldClassifyWantsApproval_whenStaleButOtherFreshApproval() {
  let oldReviewDate = Date(timeIntervalSince1970: 1_000_000)
  let newCommitDate = oldReviewDate.addingTimeInterval(3600)
  let myReview = Review(authorLogin: me, state: .approved, submittedAt: oldReviewDate)
  let aliceReview = Review(
    authorLogin: "alice", state: .approved,
    submittedAt: newCommitDate.addingTimeInterval(60))
  let pr = makePR(
    latestCommitDate: newCommitDate,
    everRequestedUsers: [me],
    latestReviews: [myReview, aliceReview]
  )
  let result = BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams)
  #expect(!result.needsApproval)
  #expect(result.wantsApproval)
  #expect(result.staleFlag)
}

@Test("should classify as wants-approval when never reviewed but someone else approved")
func shouldClassifyWantsApproval_whenNeverReviewedButOtherApproved() {
  let commitDate = Date(timeIntervalSince1970: 1_000_000)
  let aliceReview = Review(
    authorLogin: "alice", state: .approved,
    submittedAt: commitDate.addingTimeInterval(60))
  let pr = makePR(
    latestCommitDate: commitDate,
    currentlyRequestedUsers: [me],
    everRequestedUsers: [me],
    latestReviews: [aliceReview]
  )
  let result = BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams)
  #expect(result.wantsApproval)
  #expect(!result.needsApproval)
  #expect(!result.staleFlag)
}

@Test("should classify as needs-approval (stale) when my review was dismissed by new commits")
func shouldClassifyStale_whenMyApprovalDismissed() {
  let oldReviewDate = Date(timeIntervalSince1970: 1_000_000)
  let newCommitDate = oldReviewDate.addingTimeInterval(3600)
  let dismissed = Review(authorLogin: me, state: .dismissed, submittedAt: oldReviewDate)
  let pr = makePR(
    latestCommitDate: newCommitDate,
    currentlyRequestedUsers: [],  // GitHub did NOT re-request
    everRequestedUsers: [me],
    latestReviews: [dismissed]
  )
  let result = BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams)
  #expect(result.needsApproval)
  #expect(result.staleFlag)
}

@Test("should classify as needs-approval when my team is currently requested")
func shouldClassifyNeedsApproval_whenTeamRequested() {
  let team = TeamRef(org: "naturalcycles", slug: "backend")
  let pr = makePR(
    currentlyRequestedTeams: [team],
    everRequestedTeams: [team]
  )
  let result = BucketClassifier.classify(pr: pr, me: me, myTeams: [team])
  #expect(result.needsApproval)
}

@Test("should drop when team was removed and I never reviewed")
func shouldDrop_whenTeamRemovedAndNeverReviewed() {
  let team = TeamRef(org: "naturalcycles", slug: "backend")
  let pr = makePR(
    currentlyRequestedTeams: [],
    everRequestedTeams: []  // never requested at all
  )
  #expect(BucketClassifier.classify(pr: pr, me: me, myTeams: [team]).isDropped)
}

@Test("should classify as mentions-only when @-mentioned without review involvement")
func shouldClassifyMentionsOnly_whenOnlyMentioned() {
  let pr = makePR(
    commentTexts: ["hey @\(me) can you take a look later"]
  )
  let result = BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams)
  #expect(!result.needsApproval)
  #expect(!result.wantsApproval)
  #expect(result.mentions)
}

@Test("should be in both needs-approval and mentions when both apply")
func shouldBeInBothNeedsAndMentions_whenBothApply() {
  let pr = makePR(
    currentlyRequestedUsers: [me],
    everRequestedUsers: [me],
    bodyText: "ping @\(me)"
  )
  let result = BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams)
  #expect(result.needsApproval)
  #expect(result.mentions)
}

@Test("should drop drafts regardless of bucket conditions")
func shouldDropDrafts() {
  let pr = makePR(
    isDraft: true,
    currentlyRequestedUsers: [me],
    everRequestedUsers: [me],
    bodyText: "@\(me)"
  )
  #expect(BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams).isDropped)
}

@Test("should drop self-authored PRs even when mentioned")
func shouldDropSelfAuthored() {
  let pr = makePR(
    authorLogin: me,
    bodyText: "TODO for @\(me)"
  )
  #expect(BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams).isDropped)
}

@Test("should drop closed PRs")
func shouldDropClosedPRs() {
  let pr = makePR(
    state: .closed,
    currentlyRequestedUsers: [me],
    everRequestedUsers: [me]
  )
  #expect(BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams).isDropped)
}

@Test("should detect mentions in inline review-thread comments")
func shouldDetectMentionInReviewThread() {
  let pr = makePR(
    reviewThreadCommentTexts: ["nit but @\(me) what do you think"]
  )
  #expect(BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams).mentions)
}

@Test("should drop closed PRs even when mentioned")
func shouldDropClosedPRsEvenWhenMentioned() {
  let pr = makePR(
    state: .closed,
    commentTexts: ["hey @\(me) check this out"]
  )
  #expect(BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams).isDropped)
}

@Test("should not match @login when it's just a prefix of a longer handle")
func shouldNotMatchMention_whenPrefixOfLongerHandle() {
  // me = "frodi-karlsson"; the body mentions a different handle that
  // happens to share my prefix — must NOT register as a mention.
  let pr = makePR(
    commentTexts: ["heya @\(me)-doe could you look at this"]
  )
  #expect(!BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams).mentions)
}

@Test("should match @login at end of string and before non-handle characters")
func shouldMatchMention_atBoundary() {
  // GitHub handles are [a-zA-Z0-9-]; anything else (space, punctuation,
  // newline, end-of-string) is a valid mention boundary.
  let trailingComma = makePR(commentTexts: ["@\(me), please review"])
  let endOfString = makePR(commentTexts: ["thanks @\(me)"])
  let newline = makePR(commentTexts: ["ping @\(me)\nthoughts?"])
  let parens = makePR(commentTexts: ["(@\(me))"])

  #expect(BucketClassifier.classify(pr: trailingComma, me: me, myTeams: myTeams).mentions)
  #expect(BucketClassifier.classify(pr: endOfString, me: me, myTeams: myTeams).mentions)
  #expect(BucketClassifier.classify(pr: newline, me: me, myTeams: myTeams).mentions)
  #expect(BucketClassifier.classify(pr: parens, me: me, myTeams: myTeams).mentions)
}

// MARK: - Awaiting-response detection

/// Convenience for the awaiting-response tests: build a `PRComment` with
/// an explicit author + timestamp.
private func comment(by author: String, at date: Date, text: String = "") -> PRComment {
  PRComment(authorLogin: author, createdAt: date, bodyText: text)
}

@Test("should classify as needs-approval when someone replied after my comment")
func shouldClassifyNeedsApproval_whenSomeoneRepliedAfterMyComment() {
  // I asked a question, they replied — no new commits, no active review
  // request, no fresh review. The classifier should still surface it so
  // I can decide whether to approve.
  let commitDate = Date(timeIntervalSince1970: 1_000_000)
  let myCommentAt = commitDate.addingTimeInterval(3600)
  let theirReplyAt = myCommentAt.addingTimeInterval(1800)
  let pr = makePR(
    latestCommitDate: commitDate,
    everRequestedUsers: [me],
    comments: [
      comment(by: me, at: myCommentAt, text: "why not X?"),
      comment(by: "alice", at: theirReplyAt, text: "because Y"),
    ]
  )
  let result = BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams)
  #expect(result.needsApproval)
}

@Test("should ignore approval when computing 'my last activity'")
func shouldIgnoreApproval_whenComputingMyLastActivity() {
  // I approved. Later someone commented. My approval closes my
  // involvement — the follow-up comment shouldn't drag the PR back
  // into my buckets.
  let commitDate = Date(timeIntervalSince1970: 1_000_000)
  let myApprovalAt = commitDate.addingTimeInterval(3600)
  let theirLaterCommentAt = myApprovalAt.addingTimeInterval(1800)
  let pr = makePR(
    latestCommitDate: commitDate,
    everRequestedUsers: [me],
    latestReviews: [Review(authorLogin: me, state: .approved, submittedAt: myApprovalAt)],
    comments: [comment(by: "alice", at: theirLaterCommentAt, text: "small nit")]
  )
  #expect(BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams).isDropped)
}

@Test("should classify as wants-approval when I asked and someone else already approved")
func shouldClassifyWantsApproval_whenAwaitingResponseAndOtherApproved() {
  // I asked a question, they replied, and another reviewer approved
  // the current HEAD. Bucket 2 semantics: I could approve now, but
  // someone else already covered it.
  let commitDate = Date(timeIntervalSince1970: 1_000_000)
  let myCommentAt = commitDate.addingTimeInterval(600)
  let theirReplyAt = myCommentAt.addingTimeInterval(1800)
  let daveApproval = Review(
    authorLogin: "dave", state: .approved,
    submittedAt: commitDate.addingTimeInterval(60))
  let pr = makePR(
    latestCommitDate: commitDate,
    everRequestedUsers: [me],
    latestReviews: [daveApproval],
    comments: [
      comment(by: me, at: myCommentAt, text: "check on X?"),
      comment(by: "alice", at: theirReplyAt, text: "handled"),
    ]
  )
  let result = BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams)
  #expect(result.wantsApproval)
  #expect(!result.needsApproval)
}

@Test("should drop when I replied last (nobody is waiting on me)")
func shouldDrop_whenILastResponded() {
  // I approved (so the never-reviewed-but-was-requested arm doesn't
  // fire), then a conversation happened where I got the last word.
  // Nothing is waiting on me.
  let commitDate = Date(timeIntervalSince1970: 1_000_000)
  let myApprovalAt = commitDate.addingTimeInterval(300)
  let theirQuestion = commitDate.addingTimeInterval(600)
  let myReply = theirQuestion.addingTimeInterval(1800)
  let pr = makePR(
    latestCommitDate: commitDate,
    everRequestedUsers: [me],
    latestReviews: [Review(authorLogin: me, state: .approved, submittedAt: myApprovalAt)],
    comments: [
      comment(by: "alice", at: theirQuestion, text: "any concerns?"),
      comment(by: me, at: myReply, text: "no, looks good"),
    ]
  )
  #expect(BucketClassifier.classify(pr: pr, me: me, myTeams: myTeams).isDropped)
}
