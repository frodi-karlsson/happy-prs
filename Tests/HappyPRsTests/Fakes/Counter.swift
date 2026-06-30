import Foundation

/// Tiny shared reference-type counter for tests that need to mutate
/// state from inside a `@Sendable` closure (capturing a `var` directly
/// is a Swift 6 strict-concurrency error). Mark `@unchecked Sendable`
/// because test suites already serialize the surrounding work.
final class Counter: @unchecked Sendable {
  var value: Int = 0
}
