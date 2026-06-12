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
    switch event {
    case .expenseChange:
      return [.expenses, .projections]
    case .recurringChange:
      return [.recurringExpenses, .expenses, .projections]
    case .plannedChange:
      return [.plannedExpenses, .expenses, .projections]
    case .budgetChange:
      return [.budgets, .expenses, .projections]
    case .incomeChange:
      return [.income, .projections]
    case .scheduleChange:
      return [.schedules, .income, .projections, .settings]
    case .settingsChange:
      return [.settings, .moneyContext, .projections, .income, .expenses]
    case .moneyContextRefresh:
      return [.moneyContext]
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
