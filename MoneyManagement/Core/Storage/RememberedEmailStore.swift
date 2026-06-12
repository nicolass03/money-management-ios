import Foundation

enum RememberedEmailStore {
    private static let key = "money-mgmt-remembered-email"

    static var email: String? {
        UserDefaults.standard.string(forKey: key)
    }

    static func save(_ email: String) {
        UserDefaults.standard.set(email, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
