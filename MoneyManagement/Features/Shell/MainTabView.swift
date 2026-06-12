import SwiftUI

struct MainTabView: View {
    let sessionStore: SessionStore
    let themeManager: ThemeManager

    @State private var selectedTab: AppTab = .expenses
    @State private var showSettings = false
    @State private var deps: AppDependencies

    @State private var expensesViewModel: ExpensesViewModel
    @State private var budgetsViewModel: BudgetsViewModel
    @State private var incomeViewModel: IncomeViewModel
    @State private var projectionsViewModel: ProjectionsViewModel
    @State private var settingsViewModel: SettingsViewModel

    init(sessionStore: SessionStore, themeManager: ThemeManager) {
        self.sessionStore = sessionStore
        self.themeManager = themeManager
        let deps = AppDependencies(sessionStore: sessionStore)
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
        .sheet(isPresented: $showSettings) {
            SettingsView(
                sessionStore: sessionStore,
                themeManager: themeManager,
                viewModel: settingsViewModel
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            try? await deps.refreshSharedContext()
        }
    }
}
