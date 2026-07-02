import Foundation

enum ResourceKey: Hashable {
  case settings
  case moneyContext
  case expenses
  case recurringExpenses
  case plannedExpenses
  case budgets
  case income
  case schedules
  case accounts
  case projections
  case tags
  case expensePeriodView(String)
  case upcomingPayable(Int)
  case budgetExpenses(String)

  static var allBaseKeys: [ResourceKey] {
    [
      .settings,
      .moneyContext,
      .expenses,
      .recurringExpenses,
      .plannedExpenses,
      .budgets,
      .income,
      .schedules,
      .accounts,
      .projections,
      .tags,
    ]
  }
}

enum InvalidationMap {
  static func keys(for event: InvalidationEvent) -> Set<ResourceKey> {
    let periodViews: [ResourceKey] = ExpensePeriodKey.allCases.map { .expensePeriodView($0.rawValue) }
    let upcoming: ResourceKey = .upcomingPayable(ExpenseDefaults.upcomingPayableHorizonDays)
    switch event {
    case .expenseChange:
      return Set([.expenses, .projections, .accounts, upcoming] + periodViews)
    case .recurringChange:
      // Materialized recurring charges land on an account, so balances can change.
      return Set([.recurringExpenses, .expenses, .projections, .accounts, upcoming] + periodViews)
    case .plannedChange:
      return Set([.plannedExpenses, .expenses, .projections, .accounts, upcoming] + periodViews)
    case .budgetChange:
      return Set([.budgets, .expenses, .projections, upcoming] + periodViews)
    case .incomeChange:
      return Set([.income, .projections, .accounts])
    case .scheduleChange:
      return Set([.schedules, .income, .projections, .settings, .accounts] + periodViews)
    case .settingsChange:
      return Set([.settings, .moneyContext, .projections, .income, .expenses, upcoming] + periodViews)
    case .accountChange:
      // Account balances and the projection opening balance both derive from accounts.
      return Set([.accounts, .projections, .expenses, .income])
    case .moneyContextRefresh:
      return Set([.moneyContext])
    }
  }
}

enum InvalidationEvent {
  case expenseChange
  case recurringChange
  case plannedChange
  case budgetChange
  case incomeChange
  case scheduleChange
  case settingsChange
  case accountChange
  case moneyContextRefresh
}
