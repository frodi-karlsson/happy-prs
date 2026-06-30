import Testing

@testable import HappyPRs

@Test("should return token when gh exits 0 with token on stdout")
func shouldReturnToken_whenGhSucceeds() throws {
  let auth = GitHubAuth(runner: { _, _ in
    ShellResult(exitCode: 0, stdout: "gho_abc123\n", stderr: "")
  })
  #expect(try auth.token() == "gho_abc123")
}

@Test("should cache token across calls and re-fetch after invalidate")
func shouldCacheToken_andRefetchAfterInvalidate() throws {
  var calls = 0
  let auth = GitHubAuth(runner: { _, _ in
    calls += 1
    return ShellResult(exitCode: 0, stdout: "gho_\(calls)\n", stderr: "")
  })
  #expect(try auth.token() == "gho_1")
  #expect(try auth.token() == "gho_1")
  #expect(calls == 1)
  auth.invalidate()
  #expect(try auth.token() == "gho_2")
  #expect(calls == 2)
}

@Test("should throw notInstalled when gh binary is missing")
func shouldThrowNotInstalled_whenGhMissing() {
  let auth = GitHubAuth(runner: { _, _ in
    throw GitHubAuth.ShellError.binaryNotFound
  })
  #expect(throws: GitHubAuthError.notInstalled) { try auth.token() }
}

@Test("should throw notAuthenticated when gh exits non-zero")
func shouldThrowNotAuthenticated_whenGhExitsNonZero() {
  let auth = GitHubAuth(runner: { _, _ in
    ShellResult(exitCode: 1, stdout: "", stderr: "not authenticated")
  })
  #expect(throws: GitHubAuthError.notAuthenticated) { try auth.token() }
}

@Test("should throw notAuthenticated when gh exits 0 but stdout is empty")
func shouldThrowNotAuthenticated_whenStdoutEmpty() {
  let auth = GitHubAuth(runner: { _, _ in
    ShellResult(exitCode: 0, stdout: "\n", stderr: "")
  })
  #expect(throws: GitHubAuthError.notAuthenticated) { try auth.token() }
}
