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

@Test("should snapshot active PRs only; archived PRs lose their snapshot")
func shouldSnapshotActiveOnly_notArchived() async {
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

  #expect(Set(bag.settings.lastSeenSnapshots.keys) == Set(["PR_active"]))
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

@Test("should mark a PR as new when there's no prior snapshot for its ID")
func shouldMarkAsNew_whenNoPriorSnapshot() async {
  let bag = makeStore()
  bag.settings.hasInitialized = true
  bag.settings.hasMigrated = true
  bag.settings.lastSeenSnapshots = [
    "PR_old": BucketAssignment(
      needsApproval: true, wantsApproval: false, mentions: false, staleFlag: false)
  ]
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
  bag.settings.hasMigrated = false
  bag.fetcher.result = .success([makePR(id: "PR_1"), makePR(id: "PR_2")])

  await bag.store.refresh()

  #expect(bag.notifier.notifiedBatches.isEmpty)
  #expect(bag.settings.hasInitialized == true)
  #expect(bag.settings.hasMigrated == true)
}

@Test("should suppress notifications during the one-time schema migration")
func shouldNotNotify_duringMigration() async {
  let bag = makeStore()
  // hasInitialized=true + hasMigrated=false → an upgrading user with
  // prior history but no snapshots yet. We must not flood them with
  // notifications for every active PR on the upgrade refresh.
  bag.settings.hasInitialized = true
  bag.settings.hasMigrated = false
  bag.fetcher.result = .success([
    makePR(id: "PR_1", number: 1),
    makePR(id: "PR_2", number: 2),
  ])

  await bag.store.refresh()

  #expect(bag.notifier.notifiedBatches.isEmpty)
  #expect(bag.settings.hasMigrated == true)
  // Snapshots are seeded so the next refresh has a baseline to diff against.
  #expect(bag.settings.lastSeenSnapshots.count == 2)
}

@Test("should notify when a PR newly enters an actionable bucket")
func shouldNotify_whenNewlyInActionableBucket() async {
  let bag = makeStore()
  bag.settings.hasInitialized = true
  bag.settings.hasMigrated = true
  bag.settings.lastSeenSnapshots = [
    "PR_known": BucketAssignment(
      needsApproval: true, wantsApproval: false, mentions: false, staleFlag: false)
  ]
  bag.fetcher.result = .success([
    makePR(id: "PR_known", number: 1),
    makePR(id: "PR_new", number: 2),
  ])

  await bag.store.refresh()

  let notified = (bag.notifier.notifiedBatches.first ?? []).map(\.id)
  #expect(notified == ["PR_new"])
}

@Test("should not notify when bucket state is unchanged across refreshes")
func shouldNotNotify_whenBucketStateUnchanged() async {
  let bag = makeStore()
  bag.settings.hasInitialized = true
  bag.settings.hasMigrated = true
  let pr1Bucket = BucketAssignment(
    needsApproval: true, wantsApproval: false, mentions: false, staleFlag: false)
  let pr2Bucket = pr1Bucket
  bag.settings.lastSeenSnapshots = ["PR_1": pr1Bucket, "PR_2": pr2Bucket]
  bag.fetcher.result = .success([
    makePR(id: "PR_1", number: 1),
    makePR(id: "PR_2", number: 2),
  ])

  await bag.store.refresh()

  #expect(bag.notifier.notifiedBatches.isEmpty)
}

@Test("should notify when a previously-approved PR newly becomes stale")
func shouldNotify_whenPRNewlyStale() async {
  let bag = makeStore()
  bag.settings.hasInitialized = true
  bag.settings.hasMigrated = true
  // Last time we saw this PR, it was in needs-approval with no stale flag.
  // This time the classifier marks it stale (new commits since my review)
  // — staleFlag transitions false→true, which must fire a banner.
  bag.settings.lastSeenSnapshots = [
    "PR_stale": BucketAssignment(
      needsApproval: true, wantsApproval: false, mentions: false, staleFlag: false)
  ]
  // Construct the PR so the classifier marks it stale: I have an old
  // approved review, the HEAD commit is newer than that review.
  let oldReview = Review(
    authorLogin: me, state: .approved,
    submittedAt: fixedNow.addingTimeInterval(-2 * 86_400))
  let stalePR = makePR(
    id: "PR_stale", number: 1,
    latestCommitDate: fixedNow.addingTimeInterval(-3600),  // newer than my review
    currentlyRequestedUsers: [],
    everRequestedUsers: [me],
    latestReviews: [oldReview]
  )
  bag.fetcher.result = .success([stalePR])

  await bag.store.refresh()

  let notified = (bag.notifier.notifiedBatches.first ?? []).map(\.id)
  #expect(notified == ["PR_stale"])
  // Sanity: the classifier really did mark it stale, otherwise the
  // transition test isn't proving what it claims.
  #expect(bag.store.prs.first { $0.id == "PR_stale" }?.bucket.staleFlag == true)
}

@Test("should notify when a PR auto-unarchives back into an active bucket")
func shouldNotify_whenPRAutoUnarchives() async {
  let bag = makeStore()
  bag.settings.hasInitialized = true
  bag.settings.hasMigrated = true
  // No snapshot for PR_x — it was archived previously, so we dropped
  // its snapshot. When it auto-unarchives, prev is nil and the
  // "first time seen in an active bucket" path fires.
  bag.settings.lastSeenSnapshots = [:]
  // Archive entry whose snooze has already elapsed → auto-unarchive
  // during refresh.
  bag.settings.archives = [
    ArchiveEntry(
      prID: "PR_x",
      mode: .snoozeUntil(fixedNow.addingTimeInterval(-60)),
      archivedAt: fixedNow.addingTimeInterval(-3600),
      baselineCommitDate: fixedNow.addingTimeInterval(-3600))
  ]
  bag.fetcher.result = .success([makePR(id: "PR_x", number: 1)])

  await bag.store.refresh()

  let notified = (bag.notifier.notifiedBatches.first ?? []).map(\.id)
  #expect(notified == ["PR_x"])
  // It should now be in active, not archived.
  #expect(bag.store.prs.map(\.id) == ["PR_x"])
  #expect(bag.store.archived.isEmpty)
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
