import Foundation

@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var rememberMe = false
    var errorMessage: String?
    var isLoading = false

    private let sessionStore: SessionStore

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
        if let remembered = RememberedEmailStore.email {
            email = remembered
            rememberMe = true
        }
    }

    @MainActor
    func authenticate() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await sessionStore.signIn(email: trimmedEmail, password: password)
            if rememberMe {
                RememberedEmailStore.save(trimmedEmail)
            } else {
                RememberedEmailStore.clear()
            }
        } catch {
            errorMessage = mapError(error)
        }
    }

    private func mapError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()

        if message.contains("too many") || message.contains("rate") {
            return L10n.t("$ auth failed: too many attempts, try again later")
        }

        if message.contains("network") || message.contains("internet") || message.contains("offline") {
            return L10n.t("$ auth failed: connection error")
        }

        return L10n.t("$ auth failed: invalid credentials")
    }
}
