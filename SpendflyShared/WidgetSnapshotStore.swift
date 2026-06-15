import Foundation

public enum WidgetSnapshotStore {
    private static let storageKey = "widget-snapshot-v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.suiteName)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults,
              let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public static func load() -> WidgetSnapshot? {
        guard let defaults,
              let data = defaults.data(forKey: storageKey),
              let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    public static func clear() {
        defaults?.removeObject(forKey: storageKey)
    }
}
