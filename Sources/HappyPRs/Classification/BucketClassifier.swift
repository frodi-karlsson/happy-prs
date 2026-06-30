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

        let mentionToken = "@\(me)"
        let mentionsMe =
            pr.bodyText.contains(mentionToken)
            || pr.commentTexts.contains(where: { $0.contains(mentionToken) })
            || pr.reviewSummaryTexts.contains(where: { $0.contains(mentionToken) })
            || pr.reviewThreadCommentTexts.contains(where: { $0.contains(mentionToken) })

        let needsApproval = needsMyInput && !otherApproved
        let wantsApproval = needsMyInput && otherApproved

        return BucketAssignment(
            needsApproval: needsApproval,
            wantsApproval: wantsApproval,
            mentions: mentionsMe,
            staleFlag: staleReview
        )
    }
}
