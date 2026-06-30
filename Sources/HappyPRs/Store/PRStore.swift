import Foundation
import Observation

@Observable
public final class PRStore {
  public struct ClassifiedPR: Identifiable, Equatable {
    public let pr: PullRequest
    public let bucket: BucketAssignment
    public let isNew: Bool
    public var id: String { pr.id }
  }

  public enum RefreshState: Equatable {
    case idle
    case refreshing
    case error(String)
    case rateLimited(resetAt: Date)
    case notAuthenticated
    case ghNotInstalled
  }

  public private(set) var refreshState: RefreshState = .idle
  public private(set) var lastRefreshAt: Date? = nil
  public private(set) var prs: [ClassifiedPR] = []
  public private(set) var archived: [ClassifiedPR] = []

  private let auth: GitHubAuth
  private let fetcher: PRFetcher
  private let teamResolver: TeamResolver
  private let settings: Settings

  public init(
    auth: GitHubAuth, fetcher: PRFetcher,
    teamResolver: TeamResolver, settings: Settings
  ) {
    self.auth = auth
    self.fetcher = fetcher
    self.teamResolver = teamResolver
    self.settings = settings
  }

  public func refresh() async {
    refreshState = .refreshing
    do {
      // Validate auth up-front so we can show a useful error.
      _ = try auth.token()
    } catch GitHubAuth.AuthError.notInstalled {
      refreshState = .ghNotInstalled
      return
    } catch GitHubAuth.AuthError.notAuthenticated {
      refreshState = .notAuthenticated
      return
    } catch {
      refreshState = .error("\(error)")
      return
    }

    do {
      let resolution = try await teamResolver.resolve()
      let raw = try await fetcher.fetch(teams: resolution.teams)
      let seen = Set(settings.lastSeenPRIDs)
      let isFirstRun = !settings.hasInitialized
      let classified = raw.compactMap { pr -> ClassifiedPR? in
        let bucket = BucketClassifier.classify(
          pr: pr, me: resolution.viewerLogin, myTeams: resolution.teams
        )
        guard !bucket.isDropped else { return nil }
        return ClassifiedPR(pr: pr, bucket: bucket, isNew: !seen.contains(pr.id))
      }

      // Partition into active vs archived based on the archive store.
      let (active, archivedNow) = partitionByArchive(classified: classified)

      if !isFirstRun {
        let newOnes = active.filter { $0.isNew }
        if !newOnes.isEmpty {
          await Notifier.shared.notify(for: newOnes)
        }
      }
      prs = active
      archived = archivedNow
      // lastSeenPRIDs should cover everything we've shown — active and
      // archived — so re-surfacing on auto-unarchive doesn't fire a
      // notification for an already-known PR.
      settings.lastSeenPRIDs = classified.map { $0.id }
      settings.hasInitialized = true
      lastRefreshAt = Date()
      refreshState = .idle
    } catch GitHubClient.ClientError.httpError(let status, _) where status == 403 {
      refreshState = .rateLimited(resetAt: Date().addingTimeInterval(900))
    } catch {
      refreshState = .error("\(error)")
    }
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
        archivedAt: Date(),
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
    let now = Date()
    var entries = settings.archives
    var active: [ClassifiedPR] = []
    var archivedNow: [ClassifiedPR] = []

    for item in classified {
      if let entry = entries.first(where: { $0.prID == item.id }),
        entry.isActive(now: now, currentCommitDate: item.pr.latestCommitDate)
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
