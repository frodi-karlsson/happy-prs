import Foundation
import Testing

@testable import HappyPRs

private func fixture(_ name: String) throws -> Data {
  let url = Bundle.module.url(
    forResource: name, withExtension: "json",
    subdirectory: "Fixtures")!
  return try Data(contentsOf: url)
}

@Test("should decode search response into ID list and pageInfo")
func shouldDecodeSearchResponse() throws {
  let data = try fixture("search-sample")
  let result = try ResponseDecoding.decodeSearchPage(data)
  #expect(result.ids == ["PR_kwDOAAA1", "PR_kwDOAAA2"])
  #expect(result.hasNextPage == false)
}

@Test("should decode PR detail batch into PullRequest list")
func shouldDecodePRDetailBatch() throws {
  let data = try fixture("pr-detail-sample")
  let prs = try ResponseDecoding.decodePRDetails(data)
  #expect(prs.count == 1)
  let pr = prs[0]
  #expect(pr.number == 42)
  #expect(pr.repo == "naturalcycles/NCBackend3")
  #expect(pr.authorLogin == "alice")
  #expect(pr.state == .open)
  #expect(pr.currentlyRequestedUsers == ["frodi-karlsson"])
  #expect(pr.everRequestedUsers == ["frodi-karlsson"])
  #expect(pr.comments.map(\.bodyText) == ["lgtm @frodi-karlsson?"])
  #expect(pr.comments.map(\.authorLogin) == ["alice"])
}

@Test("should decode viewer-and-teams payload")
func shouldDecodeViewerAndTeams() throws {
  let data = try fixture("viewer-teams-sample")
  let v = try ResponseDecoding.decodeViewerAndTeams(data)
  #expect(v.viewerLogin == "frodi-karlsson")
  #expect(
    v.teams == [
      TeamRef(org: "naturalcycles", slug: "backend"),
      TeamRef(org: "naturalcycles", slug: "platform"),
    ])
}
