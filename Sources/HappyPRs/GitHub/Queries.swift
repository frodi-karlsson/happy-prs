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

  /// Builds Phase 1 search query strings — one per filter, since GitHub
  /// search does not actually OR these qualifiers together (empirically
  /// confirmed: a query like `review-requested:@me OR mentions:@me`
  /// returns zero results regardless of operands). The fetcher runs each
  /// query separately and unions the resulting PR IDs client-side.
  public static func buildSearchQueries(teams: [TeamRef]) -> [String] {
    let prefix = "is:open is:pr archived:false -author:@me"
    var queries: [String] = [
      "\(prefix) review-requested:@me",
      "\(prefix) mentions:@me",
      "\(prefix) reviewed-by:@me",
    ]
    for t in teams {
      queries.append("\(prefix) team-review-requested:\(t.org)/\(t.slug)")
    }
    return queries
  }
}
