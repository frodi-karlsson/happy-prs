import Foundation
import Testing

@testable import HappyPRs

// MARK: - Fixtures

private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
private let me = "frodi-karlsson"
private let myTeam = TeamRef(org: "naturalcycles", slug: "tech")

private func makePR(
  id: String = "PR_default",
  number: Int = 1,
  state: PRState = .open,
  isDraft: Bool = false,
  authorLogin: String = "alice",
  latestCommitDate: Date = fixedNow.addingTimeInterval(-3600),
  currentlyRequestedUsers: [String] = [me],
  currentlyRequestedTeams: [TeamRef] = [],
  everRequestedUsers: [String] = [me],
  everRequestedTeams: [TeamRef] = [],
  latestReviews: [Review] = [],
  bodyText: String = "",
  commentTexts: [String] = [],
  reviewSummaryTexts: [String] = [],
  reviewThreadCommentTexts: [String] = []
) -> PullRequest {
  PullRequest(
    id: id,
    repo: "org/repo",
    number: number,
    title: "title \(number)",
    url: URL(string: "https://example.com/\(number)")!,
    authorLogin: authorLogin,
    state: state,
    isDraft: isDraft,
    latestCommitDate: latestCommitDate,
    currentlyRequestedUsers: currentlyRequestedUsers,
    currentlyRequestedTeams: currentlyRequestedTeams,
    everRequestedUsers: everRequestedUsers,
    everRequestedTeams: everRequestedTeams,
    latestReviews: latestReviews,
    bodyText: bodyText,
    commentTexts: commentTexts,
    reviewSummaryTexts: reviewSummaryTexts,
    reviewThreadCommentTexts: reviewThreadCommentTexts
  )
}

/// Build a fully-wired PRStore with the supplied fakes.
private func makeStore(
  auth: FakeTokenProvider = FakeTokenProvider(),
  fetcher: FakePRFetcher = FakePRFetcher(),
  teamResolver: FakeTeamResolver = FakeTeamResolver(),
  settings: InMemorySettings = InMemorySettings(),
  notifier: FakeNotifier = FakeNotifier(),
  now: Date = fixedNow
) -> (
  store: PRStore, auth: FakeTokenProvider, fetcher: FakePRFetcher,
  resolver: FakeTeamResolver, settings: InMemorySettings, notifier: FakeNotifier
) {
  teamResolver.resolveResult = .success(
    TeamResolution(viewerLogin: me, teams: [myTeam]))
  let store = PRStore(
    auth: auth, fetcher: fetcher, teamResolver: teamResolver,
    settings: settings, notifier: notifier, now: { now })
  return (store, auth, fetcher, teamResolver, settings, notifier)
}

// MARK: - Auth-path mapping

@Test("should set ghNotInstalled when token() throws notInstalled")
func shouldSetGhNotInstalled_whenTokenThrowsNotInstalled() async {
  let bag = makeStore()
  bag.auth.tokenResult = .failure(GitHubAuthError.notInstalled)

  await bag.store.refresh()

  #expect(bag.store.refreshState == .ghNotInstalled)
  #expect(bag.fetcher.fetchCount == 0)
}

@Test("should set notAuthenticated when token() throws notAuthenticated")
func shouldSetNotAuthenticated_whenTokenThrowsNotAuthenticated() async {
  let bag = makeStore()
  bag.auth.tokenResult = .failure(GitHubAuthError.notAuthenticated)

  await bag.store.refresh()

  #expect(bag.store.refreshState == .notAuthenticated)
  #expect(bag.fetcher.fetchCount == 0)
}

@Test("should set error state when token() throws an unexpected error")
func shouldSetError_whenTokenThrowsUnexpected() async {
  struct Boom: Error {}
  let bag = makeStore()
  bag.auth.tokenResult = .failure(Boom())

  await bag.store.refresh()

  if case .error = bag.store.refreshState { /* ok */
  } else {
    Issue.record("expected .error, got \(bag.store.refreshState)")
  }
}

// MARK: - Happy path + lifecycle

@Test("should populate prs, lastRefreshAt, and hasInitialized on success")
func shouldPopulateState_onSuccess() async {
  let bag = makeStore()
  let pr = makePR(id: "PR_1", number: 1)
  bag.fetcher.result = .success([pr])

  await bag.store.refresh()

  #expect(bag.store.refreshState == .idle)
  #expect(bag.store.lastRefreshAt == fixedNow)
  #expect(bag.settings.hasInitialized == true)
  #expect(bag.store.prs.count == 1)
  #expect(bag.store.prs[0].pr.id == "PR_1")
}

@Test("should pass the resolved teams down to the fetcher")
func shouldPassResolvedTeams_toFetcher() async {
  let bag = makeStore()
  bag.fetcher.result = .success([])

  await bag.store.refresh()

  #expect(bag.fetcher.lastTeams == [myTeam])
}

@Test("should record all classified IDs in lastSeenPRIDs (active + archived)")
func shouldRecordAllClassifiedIDs_inLastSeen() async {
  let bag = makeStore()
  let active = makePR(id: "PR_active", number: 1)
  let archivedPR = makePR(id: "PR_archived", number: 2)
  bag.settings.archives = [
    ArchiveEntry(
      prID: "PR_archived", mode: .forever,
      archivedAt: fixedNow.addingTimeInterval(-100),
      baselineCommitDate: archivedPR.latestCommitDate)
  ]
  bag.fetcher.result = .success([active, archivedPR])

  await bag.store.refresh()

  #expect(Set(bag.settings.lastSeenPRIDs) == Set(["PR_active", "PR_archived"]))
}

// MARK: - Error mapping below the auth gate

@Test("should set rateLimited when fetcher throws 403 httpError")
func shouldSetRateLimited_when403() async {
  let bag = makeStore()
  bag.fetcher.result = .failure(
    GitHubClientError.httpError(status: 403, body: "rate limit"))

  await bag.store.refresh()

  if case .rateLimited(let resetAt) = bag.store.refreshState {
    #expect(resetAt == fixedNow.addingTimeInterval(900))
  } else {
    Issue.record("expected .rateLimited, got \(bag.store.refreshState)")
  }
}

@Test("should set error state for non-403 fetcher failures")
func shouldSetError_forNon403Failure() async {
  struct Boom: Error {}
  let bag = makeStore()
  bag.fetcher.result = .failure(Boom())

  await bag.store.refresh()

  if case .error = bag.store.refreshState { /* ok */
  } else {
    Issue.record("expected .error, got \(bag.store.refreshState)")
  }
}

// MARK: - Classification integration

@Test("should drop PRs whose classification is dropped (e.g. drafts)")
func shouldDropDrafts() async {
  let bag = makeStore()
  let real = makePR(id: "PR_keep", number: 1)
  let draft = makePR(id: "PR_draft", number: 2, isDraft: true)
  bag.fetcher.result = .success([real, draft])

  await bag.store.refresh()

  #expect(bag.store.prs.map(\.id) == ["PR_keep"])
}

@Test("should mark a PR as new when its ID isn't in lastSeenPRIDs")
func shouldMarkAsNew_whenNotInSeenSet() async {
  let bag = makeStore()
  bag.settings.lastSeenPRIDs = ["PR_old"]
  bag.settings.hasInitialized = true
  let known = makePR(id: "PR_old", number: 1)
  let fresh = makePR(id: "PR_new", number: 2)
  bag.fetcher.result = .success([known, fresh])

  await bag.store.refresh()

  let byId = Dictionary(uniqueKeysWithValues: bag.store.prs.map { ($0.id, $0.isNew) })
  #expect(byId["PR_old"] == false)
  #expect(byId["PR_new"] == true)
}

// MARK: - First-run gate

@Test("should not notify on the first refresh after install")
func shouldNotNotify_onFirstRun() async {
  let bag = makeStore()
  bag.settings.hasInitialized = false
  bag.fetcher.result = .success([makePR(id: "PR_1"), makePR(id: "PR_2")])

  await bag.store.refresh()

  #expect(bag.notifier.notifiedBatches.isEmpty)
  #expect(bag.settings.hasInitialized == true)
}

@Test("should notify for new PRs on subsequent refreshes")
func shouldNotify_forNewPRsAfterFirstRun() async {
  let bag = makeStore()
  bag.settings.hasInitialized = true
  bag.settings.lastSeenPRIDs = ["PR_known"]
  bag.fetcher.result = .success([
    makePR(id: "PR_known", number: 1),
    makePR(id: "PR_new", number: 2),
  ])

  await bag.store.refresh()

  #expect(bag.notifier.notifiedBatches.count == 1)
  let batch = bag.notifier.notifiedBatches.first ?? []
  #expect(batch.map(\.id) == ["PR_new"])
}

@Test("should not notify when nothing in the fetch is new")
func shouldNotNotify_whenNothingNew() async {
  let bag = makeStore()
  bag.settings.hasInitialized = true
  bag.settings.lastSeenPRIDs = ["PR_1", "PR_2"]
  bag.fetcher.result = .success([
    makePR(id: "PR_1", number: 1),
    makePR(id: "PR_2", number: 2),
  ])

  await bag.store.refresh()

  #expect(bag.notifier.notifiedBatches.isEmpty)
}

// MARK: - Archive partitioning during refresh

@Test("should put PRs with active archive entries into archived, not prs")
func shouldPartitionActiveArchiveEntries() async {
  let bag = makeStore()
  let archivedPR = makePR(id: "PR_archived", number: 1)
  let activePR = makePR(id: "PR_active", number: 2)
  bag.settings.archives = [
    ArchiveEntry(
      prID: "PR_archived", mode: .forever,
      archivedAt: fixedNow.addingTimeInterval(-3600),
      baselineCommitDate: archivedPR.latestCommitDate)
  ]
  bag.fetcher.result = .success([archivedPR, activePR])

  await bag.store.refresh()

  #expect(bag.store.prs.map(\.id) == ["PR_active"])
  #expect(bag.store.archived.map(\.id) == ["PR_archived"])
}

@Test("should auto-unarchive a snoozed PR once the snooze deadline passes")
func shouldAutoUnarchive_whenSnoozeElapsed() async {
  let bag = makeStore()
  let pr = makePR(id: "PR_x", number: 1)
  let snoozeUntil = fixedNow.addingTimeInterval(-60)  // already past
  bag.settings.archives = [
    ArchiveEntry(
      prID: "PR_x", mode: .snoozeUntil(snoozeUntil),
      archivedAt: fixedNow.addingTimeInterval(-3600),
      baselineCommitDate: pr.latestCommitDate)
  ]
  bag.fetcher.result = .success([pr])

  await bag.store.refresh()

  #expect(bag.store.prs.map(\.id) == ["PR_x"])
  #expect(bag.store.archived.isEmpty)
  #expect(bag.settings.archives.isEmpty)
}

@Test("should auto-unarchive untilActivity PR when HEAD has advanced")
func shouldAutoUnarchive_whenActivityAfterUntilActivity() async {
  let bag = makeStore()
  let baseline = fixedNow.addingTimeInterval(-7200)
  let pr = makePR(
    id: "PR_x", number: 1,
    latestCommitDate: fixedNow.addingTimeInterval(-60))  // newer than baseline
  bag.settings.archives = [
    ArchiveEntry(
      prID: "PR_x", mode: .untilActivity,
      archivedAt: baseline, baselineCommitDate: baseline)
  ]
  bag.fetcher.result = .success([pr])

  await bag.store.refresh()

  #expect(bag.store.prs.map(\.id) == ["PR_x"])
  #expect(bag.settings.archives.isEmpty)
}

@Test("should prune archive entries for PRs no longer present in the fetch")
func shouldPruneArchiveEntries_whenPRMissing() async {
  let bag = makeStore()
  bag.settings.archives = [
    ArchiveEntry(
      prID: "PR_gone", mode: .forever,
      archivedAt: fixedNow.addingTimeInterval(-100),
      baselineCommitDate: fixedNow)
  ]
  bag.fetcher.result = .success([])

  await bag.store.refresh()

  #expect(bag.settings.archives.isEmpty)
}

// MARK: - Archive / unarchive actions

@Test("should move a PR from prs to archived and persist the entry")
func shouldArchiveAction_movesAndPersists() async {
  let bag = makeStore()
  let pr = makePR(id: "PR_x", number: 1)
  bag.fetcher.result = .success([pr])
  await bag.store.refresh()

  bag.store.archive(id: "PR_x", mode: .forever)

  #expect(bag.store.prs.isEmpty)
  #expect(bag.store.archived.map(\.id) == ["PR_x"])
  #expect(bag.settings.archives.count == 1)
  let entry = bag.settings.archives[0]
  #expect(entry.prID == "PR_x")
  #expect(entry.mode == .forever)
  #expect(entry.archivedAt == fixedNow)
  #expect(entry.baselineCommitDate == pr.latestCommitDate)
}

@Test("should move a PR from archived back to prs and drop the entry")
func shouldUnarchiveAction_reverses() async {
  let bag = makeStore()
  let pr = makePR(id: "PR_x", number: 1)
  bag.settings.archives = [
    ArchiveEntry(
      prID: "PR_x", mode: .forever,
      archivedAt: fixedNow.addingTimeInterval(-3600),
      baselineCommitDate: pr.latestCommitDate)
  ]
  bag.fetcher.result = .success([pr])
  await bag.store.refresh()

  bag.store.unarchive(id: "PR_x")

  #expect(bag.store.prs.map(\.id) == ["PR_x"])
  #expect(bag.store.archived.isEmpty)
  #expect(bag.settings.archives.isEmpty)
}

@Test("should no-op when archiving a PR ID not currently shown")
func shouldArchiveAction_noOp_whenIDUnknown() async {
  let bag = makeStore()
  bag.fetcher.result = .success([])
  await bag.store.refresh()

  bag.store.archive(id: "PR_unknown", mode: .forever)

  #expect(bag.settings.archives.isEmpty)
}

@Test("should no-op when unarchiving a PR ID not in the archived list")
func shouldUnarchiveAction_noOp_whenIDUnknown() async {
  let bag = makeStore()
  bag.fetcher.result = .success([])
  await bag.store.refresh()

  bag.store.unarchive(id: "PR_unknown")

  #expect(bag.settings.archives.isEmpty)
}
