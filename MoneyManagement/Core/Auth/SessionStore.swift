import Foundation
import Supabase

@Observable
final class SessionStore {
    private(set) var session: Session?
    private(set) var hasReceivedInitialSession = false
    private let authService: AuthService
    private var listenTask: Task<Void, Never>?

    var isAuthenticated: Bool {
        guard let session, !session.isExpired else { return false }
        return true
    }

    /// True until the first auth event arrives, or while an expired stored session is refreshing.
    var isBootstrapping: Bool {
        !hasReceivedInitialSession || session?.isExpired == true
    }

    init(authService: AuthService) {
        self.authService = authService
        listenForAuthChanges()
    }

    deinit {
        listenTask?.cancel()
    }

    func signIn(email: String, password: String) async throws {
        try await authService.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await authService.signOut()
    }

    private func listenForAuthChanges() {
        listenTask = Task { [weak self] in
            guard let self else { return }
            for await change in authService.client.auth.authStateChanges {
                guard [.initialSession, .signedIn, .signedOut, .tokenRefreshed].contains(change.event) else {
                    continue
                }
                await MainActor.run {
                    if change.event == .initialSession {
                        self.hasReceivedInitialSession = true
                    }
                    self.session = change.session
                }
            }
        }
    }
}
