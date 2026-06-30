import Foundation

public enum ArchiveMode: Codable, Sendable, Equatable {
    case untilActivity
    case forever
    case snoozeUntil(Date)
}

public struct ArchiveEntry: Codable, Sendable, Equatable, Identifiable {
    public let prID: String
    public let mode: ArchiveMode
    public let archivedAt: Date
    public let baselineCommitDate: Date

    public var id: String { prID }

    public init(prID: String, mode: ArchiveMode, archivedAt: Date, baselineCommitDate: Date) {
        self.prID = prID
        self.mode = mode
        self.archivedAt = archivedAt
        self.baselineCommitDate = baselineCommitDate
    }

    /// Whether this archive should still hide the PR.
    /// Returns false when the PR should auto-unarchive.
    public func isActive(now: Date, currentCommitDate: Date) -> Bool {
        switch mode {
        case .forever:
            return true
        case .untilActivity:
            return currentCommitDate <= baselineCommitDate
        case .snoozeUntil(let until):
            return now < until
        }
    }
}
