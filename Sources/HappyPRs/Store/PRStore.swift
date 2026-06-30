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

    private let auth: GitHubAuth
    private let fetcher: PRFetcher
    private let teamResolver: TeamResolver
    private let settings: Settings

    public init(auth: GitHubAuth, fetcher: PRFetcher,
                teamResolver: TeamResolver, settings: Settings) {
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
            if !isFirstRun {
                let newOnes = classified.filter { $0.isNew }
                if !newOnes.isEmpty {
                    await Notifier.shared.notify(for: newOnes)
                }
            }
            prs = classified
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
}
