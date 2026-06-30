import Foundation
import Testing

@testable import HappyPRs

@Test("should construct a PullRequest with required fields")
func shouldConstructPullRequest() {
  let pr = PullRequest(
    id: "PR_1",
    repo: "frodi-karlsson/happy-prs",
    number: 42,
    title: "Add menubar UI",
    url: URL(string: "https://github.com/frodi-karlsson/happy-prs/pull/42")!,
    authorLogin: "alice",
    state: .open,
    isDraft: false,
    latestCommitDate: Date(timeIntervalSince1970: 1_000_000),
    currentlyRequestedUsers: ["frodi-karlsson"],
    currentlyRequestedTeams: [],
    everRequestedUsers: ["frodi-karlsson"],
    everRequestedTeams: [],
    latestReviews: [],
    bodyText: "",
    commentTexts: [],
    reviewSummaryTexts: [],
    reviewThreadCommentTexts: []
  )
  #expect(pr.number == 42)
  #expect(pr.state == .open)
}
