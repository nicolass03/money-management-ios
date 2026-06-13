import Foundation

/// Prevents stale async load results from surfacing errors after a newer load starts.
@MainActor
struct LoadGeneration {
  private(set) var value = 0

  mutating func next() -> Int {
    value += 1
    return value
  }

  func isCurrent(_ token: Int) -> Bool {
    value == token
  }
}

@MainActor
func shouldSurfaceLoadError(_ error: Error, isCurrent: Bool) -> Bool {
  guard isCurrent else { return false }
  if error is CancellationError { return false }
  if let urlError = error as? URLError, urlError.code == .cancelled { return false }
  return true
}
