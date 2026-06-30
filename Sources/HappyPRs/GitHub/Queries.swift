import Foundation

public enum Queries {
    /// Phase 1: combined search returning PR node IDs.
    /// Variables: `query: String`, `cursor: String?` (or null for first page).
    public static let searchPRs = #"""
    query Search($query: String!, $cursor: String) {
      search(type: ISSUE, query: $query, first: 100, after: $cursor) {
        pageInfo { endCursor hasNextPage }
        nodes {
          ... on PullRequest { id }
        }
      }
      rateLimit { remaining resetAt }
    }
    """#

    /// Phase 2: detail batch. Variables: `ids: [ID!]!`, `me: String!`.
    public static let prDetails = #"""
    query Details($ids: [ID!]!) {
      nodes(ids: $ids) {
        ... on PullRequest {
          id number url title isDraft state
          author { login }
          repository { nameWithOwner }
          reviewDecision
          reviewRequests(first: 50) {
            nodes { requestedReviewer {
              ... on User { login }
              ... on Team { slug organization { login } }
            }}
          }
          latestReviews(first: 50) {
            nodes { author { login } state submittedAt }
          }
          commits(last: 1) {
            nodes { commit { committedDate } }
          }
          bodyText
          comments(last: 50) { nodes { bodyText } }
          reviews(last: 50) { nodes { bodyText } }
          reviewThreads(last: 50) {
            nodes { comments(last: 20) { nodes { bodyText } } }
          }
          timelineItems(last: 100, itemTypes: [REVIEW_REQUESTED_EVENT]) {
            nodes {
              ... on ReviewRequestedEvent {
                requestedReviewer {
                  ... on User { login }
                  ... on Team { slug organization { login } }
                }
              }
            }
          }
        }
      }
    }
    """#

    /// Viewer + team memberships for team auto-discovery.
    public static let viewerAndTeams = #"""
    query ViewerAndTeams($me: String!) {
      viewer { login }
      user(login: $me) {
        organizations(first: 50) {
          nodes {
            login
            teams(first: 100, userLogins: [$me]) { nodes { slug } }
          }
        }
      }
    }
    """#

    /// Builds the Phase 1 search query string from teams.
    /// Format: `is:open is:pr archived:false -author:@me (review-requested:@me OR team-review-requested:org/slug OR ... OR mentions:@me OR reviewed-by:@me)`
    public static func buildSearchQuery(teams: [TeamRef]) -> String {
        var clauses = ["review-requested:@me", "mentions:@me", "reviewed-by:@me"]
        for t in teams {
            clauses.append("team-review-requested:\(t.org)/\(t.slug)")
        }
        return "is:open is:pr archived:false -author:@me (" + clauses.joined(separator: " OR ") + ")"
    }
}
