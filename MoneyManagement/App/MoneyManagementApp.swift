import SwiftUI

@main
struct MoneyManagementApp: App {
    @State private var sessionStore: SessionStore
    @State private var themeManager = ThemeManager()

    init() {
        let authService = AuthService()
        _sessionStore = State(initialValue: SessionStore(authService: authService))
    }

    var body: some Scene {
        WindowGroup {
            RootView(sessionStore: sessionStore, themeManager: themeManager)
                .appTheme(themeManager)
        }
    }
}

private struct RootView: View {
    let sessionStore: SessionStore
    let themeManager: ThemeManager
    @State private var loginViewModel: LoginViewModel

    init(sessionStore: SessionStore, themeManager: ThemeManager) {
        self.sessionStore = sessionStore
        self.themeManager = themeManager
        _loginViewModel = State(initialValue: LoginViewModel(sessionStore: sessionStore))
    }

    var body: some View {
        Group {
            if sessionStore.isBootstrapping {
                LoadingIndicator(label: "connecting")
            } else if sessionStore.isAuthenticated {
                MainTabView(sessionStore: sessionStore, themeManager: themeManager)
            } else {
                LoginView(viewModel: loginViewModel, themeManager: themeManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessionStore.isBootstrapping)
        .animation(.easeInOut(duration: 0.3), value: sessionStore.isAuthenticated)
    }
}
