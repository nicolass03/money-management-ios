import SwiftUI

@main
struct MoneyManagementApp: App {
    @State private var sessionStore: SessionStore
    @State private var themeManager = ThemeManager()
    @State private var languageManager = LanguageManager()

    init() {
        let authService = AuthService()
        _sessionStore = State(initialValue: SessionStore(authService: authService))
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                sessionStore: sessionStore,
                themeManager: themeManager,
                languageManager: languageManager
            )
                .appTheme(themeManager)
                .environment(\.locale, languageManager.locale)
        }
    }
}

private struct RootView: View {
    let sessionStore: SessionStore
    let themeManager: ThemeManager
    let languageManager: LanguageManager
    @State private var loginViewModel: LoginViewModel

    init(
        sessionStore: SessionStore,
        themeManager: ThemeManager,
        languageManager: LanguageManager
    ) {
        self.sessionStore = sessionStore
        self.themeManager = themeManager
        self.languageManager = languageManager
        _loginViewModel = State(initialValue: LoginViewModel(sessionStore: sessionStore))
    }

    var body: some View {
        Group {
            if sessionStore.isBootstrapping {
                LoadingIndicator(label: L10n.t("connecting"))
            } else if sessionStore.isAuthenticated {
                MainTabView(
                    sessionStore: sessionStore,
                    themeManager: themeManager,
                    languageManager: languageManager
                )
            } else {
                LoginView(viewModel: loginViewModel, themeManager: themeManager)
            }
        }
        .id(languageManager.language)
        .animation(.easeInOut(duration: 0.3), value: sessionStore.isBootstrapping)
        .animation(.easeInOut(duration: 0.3), value: sessionStore.isAuthenticated)
    }
}
