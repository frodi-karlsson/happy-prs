import Testing
import Foundation
@testable import HappyPRs

@Test("should keep forever-archive active indefinitely")
func shouldKeepForeverArchiveActive() {
    let entry = ArchiveEntry(
        prID: "x", mode: .forever,
        archivedAt: Date(timeIntervalSince1970: 1_000_000),
        baselineCommitDate: Date(timeIntervalSince1970: 1_000_000)
    )
    #expect(entry.isActive(
        now: Date(timeIntervalSince1970: 1_000_000 + 365 * 86_400),
        currentCommitDate: Date(timeIntervalSince1970: 1_000_000 + 365 * 86_400)
    ))
}

@Test("should keep untilActivity archive active while HEAD hasn't moved")
func shouldKeepUntilActivityActive_whenNoActivity() {
    let baseline = Date(timeIntervalSince1970: 1_000_000)
    let entry = ArchiveEntry(
        prID: "x", mode: .untilActivity, archivedAt: baseline, baselineCommitDate: baseline
    )
    #expect(entry.isActive(now: baseline.addingTimeInterval(3600), currentCommitDate: baseline))
}

@Test("should auto-unarchive untilActivity when a new commit lands")
func shouldAutoUnarchive_whenUntilActivityAndNewCommit() {
    let baseline = Date(timeIntervalSince1970: 1_000_000)
    let entry = ArchiveEntry(
        prID: "x", mode: .untilActivity, archivedAt: baseline, baselineCommitDate: baseline
    )
    #expect(!entry.isActive(
        now: baseline.addingTimeInterval(3600),
        currentCommitDate: baseline.addingTimeInterval(120)
    ))
}

@Test("should keep snooze archive active before the snooze deadline")
func shouldKeepSnoozeActive_beforeDeadline() {
    let snoozeEnd = Date(timeIntervalSince1970: 1_000_000)
    let entry = ArchiveEntry(
        prID: "x", mode: .snoozeUntil(snoozeEnd),
        archivedAt: snoozeEnd.addingTimeInterval(-3600),
        baselineCommitDate: snoozeEnd.addingTimeInterval(-3600)
    )
    #expect(entry.isActive(now: snoozeEnd.addingTimeInterval(-60), currentCommitDate: snoozeEnd))
}

@Test("should auto-unarchive snooze once the snooze deadline passes")
func shouldAutoUnarchive_whenSnoozeElapsed() {
    let snoozeEnd = Date(timeIntervalSince1970: 1_000_000)
    let entry = ArchiveEntry(
        prID: "x", mode: .snoozeUntil(snoozeEnd),
        archivedAt: snoozeEnd.addingTimeInterval(-3600),
        baselineCommitDate: snoozeEnd.addingTimeInterval(-3600)
    )
    #expect(!entry.isActive(now: snoozeEnd.addingTimeInterval(60), currentCommitDate: snoozeEnd))
}
