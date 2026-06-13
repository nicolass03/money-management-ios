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
      return Set([.expenses, .projections, upcoming] + periodViews)
    case .recurringChange:
      return Set([.recurringExpenses, .expenses, .projections, upcoming] + periodViews)
    case .plannedChange:
      return Set([.plannedExpenses, .expenses, .projections, upcoming] + periodViews)
    case .budgetChange:
      return Set([.budgets, .expenses, .projections, upcoming] + periodViews)
    case .incomeChange:
      return Set([.income, .projections])
    case .scheduleChange:
      return Set([.schedules, .income, .projections, .settings] + periodViews)
    case .settingsChange:
      return Set([.settings, .moneyContext, .projections, .income, .expenses, upcoming] + periodViews)
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
  case moneyContextRefresh
}
