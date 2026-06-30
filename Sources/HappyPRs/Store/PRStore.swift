import Foundation
import Observation

@Observable
@MainActor
public final class PRStore {
  public private(set) var refreshState: RefreshState = .idle
  public private(set) var lastRefreshAt: Date? = nil
  public private(set) var prs: [ClassifiedPR] = []
  public private(set) var archived: [ClassifiedPR] = []

  private let auth: GitHubAuthProtocol
  private let fetcher: PRFetcherProtocol
  private let teamResolver: TeamResolverProtocol
  private let settings: SettingsProtocol
  private let notifier: NotifierProtocol
  private let now: @Sendable () -> Date

  public init(
    auth: GitHubAuthProtocol,
    fetcher: PRFetcherProtocol,
    teamResolver: TeamResolverProtocol,
    settings: SettingsProtocol,
    notifier: NotifierProtocol,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.auth = auth
    self.fetcher = fetcher
    self.teamResolver = teamResolver
    self.settings = settings
    self.notifier = notifier
    self.now = now
  }

  public func refresh() async {
    refreshState = .refreshing
    do {
      // Validate auth up-front so we can show a useful error.
      _ = try auth.token()
    } catch GitHubAuthError.notInstalled {
      refreshState = .ghNotInstalled
      return
    } catch GitHubAuthError.notAuthenticated {
      refreshState = .notAuthenticated
      return
    } catch {
      refreshState = .error("\(error)")
      return
    }

    do {
      let resolution = try await teamResolver.resolve()
      let raw = try await fetcher.fetch(teams: resolution.teams, detailBatchSize: 50)

      let isFirstRun = !settings.hasInitialized
      // One-shot gate: existing users (hasInitialized=true) on their first
      // refresh under the snapshot model get a silent refresh that just
      // seeds the baseline.
      let migrating = settings.hasInitialized && !settings.hasMigrated

      let prevSnapshots = settings.lastSeenSnapshots

      // Pre-classify so we know the bucket for each PR before deciding
      // isNew + notify transitions.
      let preClassified: [(PullRequest, BucketAssignment)] = raw.compactMap {
        pr -> (PullRequest, BucketAssignment)? in
        let bucket = BucketClassifier.classify(
          pr: pr, me: resolution.viewerLogin, myTeams: resolution.teams
        )
        guard !bucket.isDropped else { return nil }
        return (pr, bucket)
      }

      // During migration, seed effectivePrev with the current state so
      // neither isNew dots nor notifications fire this once.
      let effectivePrev: [String: BucketAssignment] =
        migrating
        ? Dictionary(uniqueKeysWithValues: preClassified.map { ($0.0.id, $0.1) })
        : prevSnapshots

      let classified = preClassified.map { pr, bucket in
        ClassifiedPR(pr: pr, bucket: bucket, isNew: effectivePrev[pr.id] == nil)
      }

      // Partition into active vs archived based on the archive store.
      let (active, archivedNow) = partitionByArchive(classified: classified)

      if !isFirstRun && !migrating {
        let notifiable = active.filter { item in
          Self.shouldNotify(prev: effectivePrev[item.id], current: item.bucket)
        }
        if !notifiable.isEmpty {
          await notifier.notify(for: notifiable)
        }
      }

      // Persist snapshots for ACTIVE PRs only. Archived/dropped PRs lose
      // their snapshot, so when they later re-emerge into an active
      // bucket they're treated as "first time seen" again — which is
      // the right behaviour for both `isNew` dots and notifications.
      var newSnapshots: [String: BucketAssignment] = [:]
      for item in active {
        newSnapshots[item.id] = item.bucket
      }

      // Sort most-recently-active first so the popover is stable
      // across refreshes (PRFetcher dedupes through a Set, so its
      // own output order is non-deterministic).
      prs = active.sorted { $0.pr.latestCommitDate > $1.pr.latestCommitDate }
      archived = archivedNow.sorted { $0.pr.latestCommitDate > $1.pr.latestCommitDate }
      settings.lastSeenSnapshots = newSnapshots
      settings.hasInitialized = true
      settings.hasMigrated = true
      lastRefreshAt = now()
      refreshState = .idle
    } catch GitHubClientError.httpError(let status, _) where status == 403 {
      refreshState = .rateLimited(resetAt: now().addingTimeInterval(900))
    } catch {
      refreshState = .error("\(error)")
    }
  }

  /// Returns true when the bucket state for a PR has meaningfully
  /// changed in a direction the user wants a banner for — newly in an
  /// actionable bucket, or newly stale.
  private static func shouldNotify(
    prev: BucketAssignment?, current: BucketAssignment
  ) -> Bool {
    guard let prev else {
      // First time we've seen this PR in an active bucket.
      return current.needsApproval || current.wantsApproval || current.mentions
    }
    if current.needsApproval && !prev.needsApproval { return true }
    if current.wantsApproval && !prev.wantsApproval { return true }
    if current.mentions && !prev.mentions { return true }
    if current.staleFlag && !prev.staleFlag { return true }
    return false
  }

  /// Archive a PR currently shown in `prs`. Moves it into `archived` and
  /// persists an entry in Settings so the partition is restored on next
  /// refresh.
  public func archive(id: String, mode: ArchiveMode) {
    guard let item = prs.first(where: { $0.id == id }) else { return }
    var entries = settings.archives
    entries.removeAll { $0.prID == id }
    entries.append(
      ArchiveEntry(
        prID: id,
        mode: mode,
        archivedAt: now(),
        baselineCommitDate: item.pr.latestCommitDate
      ))
    settings.archives = entries
    archived.append(item)
    prs.removeAll { $0.id == id }
  }

  /// Remove a PR's archive entry and move it back to `prs`.
  public func unarchive(id: String) {
    guard let item = archived.first(where: { $0.id == id }) else { return }
    var entries = settings.archives
    entries.removeAll { $0.prID == id }
    settings.archives = entries
    prs.append(item)
    archived.removeAll { $0.id == id }
  }

  private func partitionByArchive(
    classified: [ClassifiedPR]
  ) -> (active: [ClassifiedPR], archived: [ClassifiedPR]) {
    let nowDate = now()
    var entries = settings.archives
    var active: [ClassifiedPR] = []
    var archivedNow: [ClassifiedPR] = []

    for item in classified {
      if let entry = entries.first(where: { $0.prID == item.id }),
        entry.isActive(now: nowDate, currentCommitDate: item.pr.latestCommitDate)
      {
        archivedNow.append(item)
      } else {
        active.append(item)
        // Auto-unarchive: the archive entry has expired or activity
        // happened; drop it so a future archive starts fresh.
        entries.removeAll { $0.prID == item.id }
      }
    }
    // Prune entries for PRs that no longer appear in the fetch (closed/merged).
    let fetchedIDs = Set(classified.map { $0.id })
    entries.removeAll { !fetchedIDs.contains($0.prID) }
    settings.archives = entries
    return (active, archivedNow)
  }
}
