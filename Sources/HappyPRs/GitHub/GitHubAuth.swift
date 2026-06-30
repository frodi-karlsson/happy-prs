import Foundation

public struct ShellResult: Sendable, Equatable {
  public let exitCode: Int32
  public let stdout: String
  public let stderr: String
}

// @unchecked because `cachedToken` is mutable. The class wraps all
// reads/writes in `cacheLock` (NSLock), so concurrent access from
// different actors is safe in practice.
public final class GitHubAuth: GitHubAuthProtocol, @unchecked Sendable {
  public enum ShellError: Error, Equatable {
    case binaryNotFound
  }

  public typealias Runner = @Sendable (_ command: String, _ args: [String]) throws -> ShellResult

  private let runner: Runner

  public init(runner: @escaping Runner = GitHubAuth.defaultRunner) {
    self.runner = runner
  }

  private var cachedToken: String?
  private let cacheLock = NSLock()

  public func token() throws -> String {
    cacheLock.lock()
    if let cachedToken { cacheLock.unlock(); return cachedToken }
    cacheLock.unlock()

    let result: ShellResult
    do {
      result = try runner("gh", ["auth", "token"])
    } catch ShellError.binaryNotFound {
      throw GitHubAuthError.notInstalled
    }
    guard result.exitCode == 0 else { throw GitHubAuthError.notAuthenticated }
    let trimmed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw GitHubAuthError.notAuthenticated }

    cacheLock.lock()
    cachedToken = trimmed
    cacheLock.unlock()
    return trimmed
  }

  /// Clears the in-memory token cache. Call after a 401 so the next `token()`
  /// re-invokes `gh auth token`.
  public func invalidate() {
    cacheLock.lock()
    cachedToken = nil
    cacheLock.unlock()
  }

  public static let defaultRunner: Runner = { command, args in
    let proc = Process()
    // Use /usr/bin/env so we don't hard-code gh's path.
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    proc.arguments = [command] + args

    // GUI apps on macOS don't inherit the shell PATH — when launched via
    // LaunchAgent or `open`, PATH is just /usr/bin:/bin:/usr/sbin:/sbin.
    // Augment with common Homebrew locations so `gh` is findable.
    var env = ProcessInfo.processInfo.environment
    let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
    let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
    env["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
    proc.environment = env

    let out = Pipe()
    let err = Pipe()
    proc.standardOutput = out
    proc.standardError = err
    do {
      try proc.run()
    } catch CocoaError.fileNoSuchFile {
      throw ShellError.binaryNotFound
    } catch let nsError as NSError where nsError.code == NSFileNoSuchFileError {
      throw ShellError.binaryNotFound
    }
    proc.waitUntilExit()
    let outData = out.fileHandleForReading.readDataToEndOfFile()
    let errData = err.fileHandleForReading.readDataToEndOfFile()
    // Exit code 127 from /usr/bin/env means "command not found".
    if proc.terminationStatus == 127 {
      throw ShellError.binaryNotFound
    }
    return ShellResult(
      exitCode: proc.terminationStatus,
      stdout: String(data: outData, encoding: .utf8) ?? "",
      stderr: String(data: errData, encoding: .utf8) ?? ""
    )
  }
}
