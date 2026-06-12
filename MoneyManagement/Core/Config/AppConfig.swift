import Foundation

enum AppBrand {
    static let name = "spendfly"
    static let version = "0.1.0"

    static var versionLabel: String { "\(name) v\(version)" }
}

enum AppConfig {
    static var supabaseURL: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !raw.isEmpty,
              !raw.hasPrefix("$("),
              let url = URL(string: raw),
              url.host != nil else {
            fatalError(
                """
                SUPABASE_URL is missing or invalid (got \"\(Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") ?? "")\").
                In Config/Secrets.xcconfig use https:/$()/your-project.supabase.co — not https:// (xcconfig treats // as a comment).
                """
            )
        }
        return url
    }

    static var supabasePublishableKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else {
            fatalError(
                "SUPABASE_PUBLISHABLE_KEY is missing. Copy Config/Secrets.xcconfig.example to Config/Secrets.xcconfig and set your publishable key."
            )
        }
        return key
    }

    static var apiURL: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
              !raw.isEmpty,
              !raw.hasPrefix("$("),
              let url = URL(string: raw),
              url.host != nil else {
            fatalError(
                """
                API_URL is missing or invalid (got \"\(Bundle.main.object(forInfoDictionaryKey: "API_URL") ?? "")\").
                In Config/Secrets.xcconfig use http:/$()/127.0.0.1:8080 — not http:// (xcconfig treats // as a comment).
                """
            )
        }
        return url
    }
}
