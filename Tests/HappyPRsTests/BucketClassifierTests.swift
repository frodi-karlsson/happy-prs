import Testing
import Foundation
@testable import HappyPRs

private let me = "frodi-karlsson"
private let myTeams: [TeamRef] = [TeamRef(org: "naturalcycles", slug: "backend")]

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
    reviewThreadCommentTexts: [String] = []
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
        bodyText: bodyText, commentTexts: commentTexts,
        reviewSummaryTexts: reviewSummaryTexts,
        reviewThreadCommentTexts: reviewThreadCommentTexts
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
    let myReview = Review(authorLogin: me, state: .approved,
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
    let aliceReview = Review(authorLogin: "alice", state: .approved,
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
    let aliceReview = Review(authorLogin: "alice", state: .approved,
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
        currentlyRequestedUsers: [],            // GitHub did NOT re-request
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
        everRequestedTeams: []                  // never requested at all
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
