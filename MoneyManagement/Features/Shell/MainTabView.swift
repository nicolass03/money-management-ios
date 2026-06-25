import SwiftUI

struct MainTabView: View {
    let sessionStore: SessionStore
    let themeManager: ThemeManager
    let languageManager: LanguageManager

    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: AppTab = .expenses
    @State private var showSettings = false
    @State private var settingsDidSave = false
    @State private var deps: AppDependencies

    @State private var expensesViewModel: ExpensesViewModel
    @State private var budgetsViewModel: BudgetsViewModel
    @State private var incomeViewModel: IncomeViewModel
    @State private var projectionsViewModel: ProjectionsViewModel
    @State private var settingsViewModel: SettingsViewModel

    init(sessionStore: SessionStore, themeManager: ThemeManager, languageManager: LanguageManager) {
        self.sessionStore = sessionStore
        self.themeManager = themeManager
        self.languageManager = languageManager
        let deps = AppDependencies(
            sessionStore: sessionStore,
            languageManager: languageManager,
            themeManager: themeManager
        )
        _deps = State(initialValue: deps)
        _expensesViewModel = State(initialValue: ExpensesViewModel(deps: deps))
        _budgetsViewModel = State(initialValue: BudgetsViewModel(deps: deps))
        _incomeViewModel = State(initialValue: IncomeViewModel(deps: deps))
        _projectionsViewModel = State(initialValue: ProjectionsViewModel(deps: deps))
        _settingsViewModel = State(initialValue: SettingsViewModel(deps: deps))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ExpensesView(
                    viewModel: expensesViewModel,
                    deps: deps,
                    onOpenSettings: { showSettings = true }
                )
            }
            .tag(AppTab.expenses)

            NavigationStack {
                BudgetsView(viewModel: budgetsViewModel, deps: deps)
            }
            .tag(AppTab.budgets)

            NavigationStack {
                IncomeView(viewModel: incomeViewModel, deps: deps)
            }
            .tag(AppTab.income)

            NavigationStack {
                ProjectionsView(
                    viewModel: projectionsViewModel,
                    deps: deps,
                    onOpenSettings: { showSettings = true }
                )
            }
            .tag(AppTab.projections)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            TerminalTabBar(selectedTab: $selectedTab)
        }
        .overlay(alignment: .topTrailing) {
            FloatingSettingsButton {
                showSettings = true
            }
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showSettings, onDismiss: handleSettingsDismiss) {
            SettingsView(
                sessionStore: sessionStore,
                themeManager: themeManager,
                languageManager: languageManager,
                viewModel: settingsViewModel,
                onSaved: { settingsDidSave = true }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                // Only reload when the server's cacheRevision changed while backgrounded;
                // syncOnForeground() invalidates the caches itself when needed.
                let changed = await deps.syncOnForeground()
                if changed {
                    await reloadActiveTab(force: false)
                    await deps.syncWidgets()
                    await deps.refreshSubscriptionReminders()
                }
            }
        }
        .task {
            await deps.syncWidgets()
            await SubscriptionReminderScheduler.requestAuthorization()
            await deps.refreshSubscriptionReminders()
        }
        .onChange(of: sessionStore.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                deps.clearWidgetSnapshot()
            }
        }
    }

    private func handleSettingsDismiss() {
        guard settingsDidSave else { return }
        settingsDidSave = false
        Task { await reloadActiveTab(force: false) }
    }

    @MainActor
    private func reloadActiveTab(force: Bool) async {
        switch selectedTab {
        case .expenses:
            await expensesViewModel.load(force: force)
        case .budgets:
            await budgetsViewModel.load(force: force)
        case .income:
            await incomeViewModel.load(force: force)
        case .projections:
            await projectionsViewModel.load(force: force)
        }
    }
}
