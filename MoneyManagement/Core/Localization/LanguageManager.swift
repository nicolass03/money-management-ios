import Foundation
import Observation

private let languageStorageKey = "incm-mgmt-language"

enum L10n {
    private static var language: AppLanguage = {
        if let raw = UserDefaults.standard.string(forKey: languageStorageKey),
           let stored = AppLanguage(rawValue: raw) {
            return stored
        }

        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return preferred.starts(with: "es") ? .es : .en
    }()

    static var locale: Locale {
        Locale(identifier: language.localeIdentifier)
    }

    static func use(_ language: AppLanguage) {
        self.language = language
    }

    static func t(_ key: String) -> String {
        guard
            let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return NSLocalizedString(key, comment: "")
        }

        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}

@Observable
final class LanguageManager {
    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: languageStorageKey)
            L10n.use(language)
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: languageStorageKey),
           let stored = AppLanguage(rawValue: raw) {
            language = stored
            L10n.use(stored)
            return
        }

        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        language = preferred.starts(with: "es") ? .es : .en
        UserDefaults.standard.set(language.rawValue, forKey: languageStorageKey)
        L10n.use(language)
    }

    var locale: Locale {
        L10n.locale
    }

    func apply(_ language: AppLanguage) {
        self.language = language
    }
}
