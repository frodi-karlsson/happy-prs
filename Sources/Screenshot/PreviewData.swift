import Foundation
import HappyPRs

// MARK: - Preview-only conformers to the library's protocols.

final class PreviewAuth: GitHubAuthProtocol, @unchecked Sendable {
  func token() throws -> String { "preview-token" }
  func invalidate() {}
}

final class PreviewFetcher: PRFetcherProtocol, @unchecked Sendable {
  let prs: [PullRequest]
  init(_ prs: [PullRequest]) { self.prs = prs }
  func fetch(teams: [TeamRef], detailBatchSize: Int) async throws -> [PullRequest] {
    prs
  }
}

final class PreviewTeamResolver: TeamResolverProtocol, @unchecked Sendable {
  let resolution: TeamResolution
  init(_ resolution: TeamResolution) { self.resolution = resolution }
  func resolve() async throws -> TeamResolution { resolution }
  func invalidate() {}
}

final class PreviewNotifier: NotifierProtocol, @unchecked Sendable {
  func notify(for items: [ClassifiedPR]) async {}
  func requestAuthorization() async {}
}

final class PreviewSettings: SettingsProtocol, @unchecked Sendable {
  var refreshIntervalSeconds: Int = 60
  var hiddenRepos: [String] = []
  var lastSeenPRIDs: [String] = []
  /// Pre-set so the real first-run gate doesn't apply (we don't want
  /// notification side-effects in preview anyway).
  var hasInitialized: Bool = true
  var archives: [ArchiveEntry] = []
}

// MARK: - Mock PR fixtures.

enum PreviewData {
  static let viewerLogin = "frodi-karlsson"
  static let team = TeamRef(org: "naturalcycles", slug: "tech")

  /// Builds a PRStore populated by running `refresh()` against in-memory
  /// fakes, with a realistic mix of PRs across all three buckets plus one
  /// archived entry. Commit dates are computed relative to `now` so the
  /// "2h ago" / "1d ago" labels stay readable across runs.
  @MainActor
  static func loadedStore(now: Date = Date()) async -> PRStore {
    let me = viewerLogin
    let prs: [PullRequest] = [
      // Bucket 1: needs approval, never reviewed, currently requested.
      pr(
        id: "PR_1", repo: "NaturalCycles/NCBackend3", number: 4821,
        title: "fix(migrations): resolve deadlock on backfill",
        author: "alice",
        latestCommitDate: now.addingTimeInterval(-2 * 3600),
        currentlyRequested: [me], everRequested: [me]
      ),
      // Bucket 1, stale: I approved long ago, new commits since.
      pr(
        id: "PR_2", repo: "NaturalCycles/NCApp3", number: 1207,
        title: "feat(signup): bigger tap targets on wizard cards",
        author: "bob",
        latestCommitDate: now.addingTimeInterval(-3 * 3600),
        currentlyRequested: [], everRequested: [me],
        latestReviews: [
          Review(
            authorLogin: me, state: .approved,
            submittedAt: now.addingTimeInterval(-2 * 86_400))
        ]
      ),
      // Bucket 2: wants approval, somebody else already approved current HEAD.
      pr(
        id: "PR_3", repo: "NaturalCycles/NCWeb", number: 4688,
        title: "feat(deps): react-router@8 and other stories",
        author: "carol",
        latestCommitDate: now.addingTimeInterval(-30 * 60),
        currentlyRequested: [me], everRequested: [me],
        latestReviews: [
          Review(
            authorLogin: "dave", state: .approved,
            submittedAt: now.addingTimeInterval(-15 * 60))
        ]
      ),
      // Bucket 3 only: @-mention with no review involvement.
      pr(
        id: "PR_4", repo: "NaturalCycles/WebSignup", number: 4400,
        title: "fix(payments): throw directly for non-payment intent errors",
        author: "eve",
        latestCommitDate: now.addingTimeInterval(-20 * 60),
        currentlyRequested: [], everRequested: [],
        commentTexts: ["thoughts on this approach @\(me)? happy to iterate"]
      ),
      // Archived: was requested, user said "let someone else handle it".
      pr(
        id: "PR_5", repo: "NaturalCycles/NCUiKit", number: 200,
        title: "chore(tokens): align dark-mode color tokens with figma",
        author: "frank",
        latestCommitDate: now.addingTimeInterval(-5 * 86_400),
        currentlyRequested: [me], everRequested: [me]
      ),
    ]

    let settings = PreviewSettings()
    // Pre-seed seen IDs for PR_1 and PR_3 so PR_2 and PR_4 render the "new"
    // dot — gives the screenshot a more varied row treatment.
    settings.lastSeenPRIDs = ["PR_1", "PR_3", "PR_5"]
    settings.archives = [
      ArchiveEntry(
        prID: "PR_5", mode: .forever,
        archivedAt: now.addingTimeInterval(-3 * 86_400),
        baselineCommitDate: now.addingTimeInterval(-5 * 86_400))
    ]

    let store = PRStore(
      auth: PreviewAuth(),
      fetcher: PreviewFetcher(prs),
      teamResolver: PreviewTeamResolver(
        TeamResolution(viewerLogin: me, teams: [team])),
      settings: settings,
      notifier: PreviewNotifier(),
      now: { now }
    )
    await store.refresh()
    return store
  }

  private static func pr(
    id: String, repo: String, number: Int, title: String, author: String,
    latestCommitDate: Date,
    currentlyRequested: [String] = [], everRequested: [String] = [],
    latestReviews: [Review] = [],
    commentTexts: [String] = []
  ) -> PullRequest {
    PullRequest(
      id: id, repo: repo, number: number, title: title,
      url: URL(string: "https://github.com/\(repo)/pull/\(number)")!,
      authorLogin: author, state: .open, isDraft: false,
      latestCommitDate: latestCommitDate,
      currentlyRequestedUsers: currentlyRequested,
      currentlyRequestedTeams: [],
      everRequestedUsers: everRequested,
      everRequestedTeams: [],
      latestReviews: latestReviews,
      bodyText: "",
      commentTexts: commentTexts,
      reviewSummaryTexts: [],
      reviewThreadCommentTexts: []
    )
  }
}
