import Testing

@testable import HappyPRs

@Test("should emit one query per filter plus one per team")
func shouldEmitOneQueryPerFilter() {
  let queries = Queries.buildSearchQueries(teams: [
    TeamRef(org: "naturalcycles", slug: "backend"),
    TeamRef(org: "naturalcycles", slug: "platform"),
  ])
  // 3 base filters + 2 teams = 5
  #expect(queries.count == 5)
  #expect(queries.contains { $0.contains("review-requested:@me") && !$0.contains("OR") })
  #expect(queries.contains { $0.contains("mentions:@me") })
  #expect(queries.contains { $0.contains("reviewed-by:@me") })
  #expect(queries.contains { $0.contains("team-review-requested:naturalcycles/backend") })
  #expect(queries.contains { $0.contains("team-review-requested:naturalcycles/platform") })
}

@Test("should emit only the three base filters when there are no teams")
func shouldEmitOnlyBaseFilters_whenNoTeams() {
  let queries = Queries.buildSearchQueries(teams: [])
  #expect(queries.count == 3)
  for q in queries {
    #expect(q.contains("is:open"))
    #expect(q.contains("is:pr"))
    #expect(q.contains("-author:@me"))
    #expect(!q.contains("OR"))
  }
}
