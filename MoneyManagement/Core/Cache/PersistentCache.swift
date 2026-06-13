import Foundation

/// Disk-backed store for the `DataStore` snapshot (stale-while-revalidate).
///
/// Reads are synchronous — a small file, read once at launch so the first paint is instant.
/// Writes are merged, debounced, and the file I/O runs off the main actor, so persistence never
/// blocks the UI even though encoding happens on-actor (the payload is small personal-finance data).
@MainActor
final class PersistentCache {
  private let fileURL: URL
  private var merged: DataStoreSnapshot?
  private var writeTask: Task<Void, Never>?

  init(fileURL: URL = PersistentCache.defaultFileURL) {
    self.fileURL = fileURL
  }

  nonisolated static var defaultFileURL: URL {
    let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    return base.appendingPathComponent("spendfly-datastore-v1.json")
  }

  /// Loads the persisted snapshot synchronously. Returns nil when absent or unreadable.
  func load() -> DataStoreSnapshot? {
    guard let data = try? Data(contentsOf: fileURL),
          let snapshot = try? JSONDecoder().decode(DataStoreSnapshot.self, from: data) else {
      return nil
    }
    merged = snapshot
    return snapshot
  }

  /// Merges `snapshot`'s non-nil fields into the retained state and schedules a debounced write.
  func save(_ snapshot: DataStoreSnapshot) {
    merged = (merged ?? DataStoreSnapshot()).merging(snapshot)
    scheduleWrite()
  }

  /// Drops the in-memory and on-disk copies (sign-out / different user).
  func clear() {
    writeTask?.cancel()
    writeTask = nil
    merged = nil
    Self.deleteStoredFile()
  }

  /// Deletes the cache file without needing an instance — used from the auth layer on sign-out.
  nonisolated static func deleteStoredFile() {
    try? FileManager.default.removeItem(at: defaultFileURL)
  }

  private func scheduleWrite() {
    writeTask?.cancel()
    guard let snapshot = merged else { return }
    let url = fileURL
    writeTask = Task {
      try? await Task.sleep(for: .milliseconds(400))
      if Task.isCancelled { return }
      // Encode on-actor (small payload), then hand the Sendable `Data` to a detached task for I/O.
      guard let data = try? JSONEncoder().encode(snapshot) else { return }
      await Self.write(data, to: url)
    }
  }

  private nonisolated static func write(_ data: Data, to url: URL) async {
    await Task.detached(priority: .utility) {
      try? data.write(to: url, options: .atomic)
    }.value
  }
}
