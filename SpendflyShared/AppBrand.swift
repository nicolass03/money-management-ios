import Foundation

/// App branding shown in the UI (app + widgets). Mirrors web `src/lib/brand.ts`.
public enum AppBrand {
    public static let name = "cash.sh"
    public static let version = "0.1.0"

    public static var versionLabel: String { "\(name) v\(version)" }
}
