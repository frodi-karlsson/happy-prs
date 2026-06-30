import Foundation

public enum ResponseDecoding {
  public struct SearchPage: Sendable, Equatable {
    public let ids: [String]
    public let endCursor: String?
    public let hasNextPage: Bool
  }

  public struct ViewerAndTeams: Sendable, Equatable {
    public let viewerLogin: String
    public let teams: [TeamRef]
  }

  public enum DecodingError: Error { case unexpectedShape(String) }

  private static let iso = ISO8601DateFormatter()

  private static func parseDate(_ s: String) -> Date? {
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: s)
  }

  public static func decodeSearchPage(_ data: Data) throws -> SearchPage {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let dataObj = root["data"] as? [String: Any],
      let search = dataObj["search"] as? [String: Any],
      let nodes = search["nodes"] as? [[String: Any]],
      let pageInfo = search["pageInfo"] as? [String: Any]
    else { throw DecodingError.unexpectedShape("search root") }
    let ids = nodes.compactMap { $0["id"] as? String }
    return SearchPage(
      ids: ids,
      endCursor: pageInfo["endCursor"] as? String,
      hasNextPage: pageInfo["hasNextPage"] as? Bool ?? false
    )
  }

  public static func decodePRDetails(_ data: Data) throws -> [PullRequest] {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let dataObj = root["data"] as? [String: Any],
      let nodes = dataObj["nodes"] as? [Any]
    else { throw DecodingError.unexpectedShape("details root") }

    var prs: [PullRequest] = []
    for node in nodes {
      guard let pr = node as? [String: Any] else { continue }
      guard let id = pr["id"] as? String,
        let number = pr["number"] as? Int,
        let urlStr = pr["url"] as? String,
        let url = URL(string: urlStr),
        let title = pr["title"] as? String,
        let isDraft = pr["isDraft"] as? Bool,
        let stateStr = pr["state"] as? String,
        let repo = (pr["repository"] as? [String: Any])?["nameWithOwner"] as? String,
        let author = (pr["author"] as? [String: Any])?["login"] as? String
      else { throw DecodingError.unexpectedShape("PullRequest core fields") }

      let state: PRState = {
        switch stateStr {
        case "OPEN": return .open
        case "MERGED": return .merged
        default: return .closed
        }
      }()

      // Latest commit date
      let commitNodes = ((pr["commits"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
      let latestCommitStr = (commitNodes.last?["commit"] as? [String: Any])?["committedDate"] as? String
      let latestCommitDate = latestCommitStr.flatMap(parseDate) ?? Date.distantPast

      // Review requests (current)
      let (curUsers, curTeams) = decodeReviewers(
        ((pr["reviewRequests"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? [],
        reviewerKey: "requestedReviewer"
      )

      // Ever requested (from timeline events)
      let (everUsers, everTeams) = decodeReviewers(
        ((pr["timelineItems"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? [],
        reviewerKey: "requestedReviewer"
      )

      // Latest reviews
      let reviewNodes = ((pr["latestReviews"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
      let latestReviews: [Review] = reviewNodes.compactMap { rn in
        guard let login = (rn["author"] as? [String: Any])?["login"] as? String,
          let stateStr = rn["state"] as? String,
          let st = ReviewState(rawValue: stateStr),
          let when = (rn["submittedAt"] as? String).flatMap(parseDate)
        else { return nil }
        return Review(authorLogin: login, state: st, submittedAt: when)
      }

      let bodyText = (pr["bodyText"] as? String) ?? ""
      let commentTexts: [String] = (((pr["comments"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? [])
        .compactMap { $0["bodyText"] as? String }
      let reviewSummaryTexts: [String] = (((pr["reviews"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? [])
        .compactMap { $0["bodyText"] as? String }
      let threadTexts: [String] = (((pr["reviewThreads"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? [])
        .flatMap { thread -> [String] in
          (((thread["comments"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? [])
            .compactMap { $0["bodyText"] as? String }
        }

      prs.append(
        PullRequest(
          id: id, repo: repo, number: number, title: title, url: url,
          authorLogin: author, state: state, isDraft: isDraft,
          latestCommitDate: latestCommitDate,
          currentlyRequestedUsers: curUsers,
          currentlyRequestedTeams: curTeams,
          everRequestedUsers: everUsers,
          everRequestedTeams: everTeams,
          latestReviews: latestReviews,
          bodyText: bodyText, commentTexts: commentTexts,
          reviewSummaryTexts: reviewSummaryTexts,
          reviewThreadCommentTexts: threadTexts
        ))
    }
    return prs
  }

  public static func decodeViewerAndTeams(_ data: Data) throws -> ViewerAndTeams {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let dataObj = root["data"] as? [String: Any],
      let viewer = dataObj["viewer"] as? [String: Any],
      let login = viewer["login"] as? String
    else { throw DecodingError.unexpectedShape("viewer root") }

    let user = dataObj["user"] as? [String: Any] ?? [:]
    let orgNodes = ((user["organizations"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
    var teams: [TeamRef] = []
    for org in orgNodes {
      guard let orgLogin = org["login"] as? String else { continue }
      let teamNodes = ((org["teams"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
      for t in teamNodes {
        if let slug = t["slug"] as? String {
          teams.append(TeamRef(org: orgLogin, slug: slug))
        }
      }
    }
    return ViewerAndTeams(viewerLogin: login, teams: teams)
  }

  private static func decodeReviewers(
    _ nodes: [[String: Any]],
    reviewerKey: String
  ) -> (users: [String], teams: [TeamRef]) {
    var users: Set<String> = []
    var teams: Set<TeamRef> = []
    for n in nodes {
      guard let rr = n[reviewerKey] as? [String: Any] else { continue }
      if let login = rr["login"] as? String {
        users.insert(login)
      } else if let slug = rr["slug"] as? String,
        let org = (rr["organization"] as? [String: Any])?["login"] as? String
      {
        teams.insert(TeamRef(org: org, slug: slug))
      }
    }
    return (users.sorted(), teams.sorted { $0.slug < $1.slug })
  }
}
