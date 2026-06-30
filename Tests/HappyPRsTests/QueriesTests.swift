import Testing
@testable import HappyPRs

@Test("should include team-review-requested for every team")
func shouldIncludeAllTeams_inSearchQuery() {
    let q = Queries.buildSearchQuery(teams: [
        TeamRef(org: "naturalcycles", slug: "backend"),
        TeamRef(org: "naturalcycles", slug: "platform"),
    ])
    #expect(q.contains("team-review-requested:naturalcycles/backend"))
    #expect(q.contains("team-review-requested:naturalcycles/platform"))
    #expect(q.contains("is:open"))
    #expect(q.contains("-author:@me"))
}

@Test("should build a valid query with no teams")
func shouldBuildValidQuery_whenNoTeams() {
    let q = Queries.buildSearchQuery(teams: [])
    #expect(q.contains("review-requested:@me"))
    #expect(q.contains("mentions:@me"))
    #expect(q.contains("reviewed-by:@me"))
}
