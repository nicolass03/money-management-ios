import Foundation
import Observation

@Observable
@MainActor
final class DataStore {
  private var invalidatedKeys = Set<ResourceKey>()
  private var inFlightTasks: [ResourceKey: Task<Any, Error>] = [:]

  private(set) var settings: UserSettings?
  private(set) var moneyContext: MoneyContextResponse?
  private(set) var expenses: [ExpenseWithTags]?
  private(set) var recurringExpenses: [RecurringExpenseWithTags]?
  private(set) var plannedExpenses: [PlannedExpenseWithTags]?
  private(set) var budgets: [BudgetWithTags]?
  private(set) var income: [Income]?
  private(set) var schedules: [IncomePaySchedule]?
  private(set) var projections: ProjectionsResponse?
  private(set) var tags: [String]?
  private(set) var expensePeriodViews: [String: ExpensePeriodViewResponse] = [:]
  private(set) var upcomingPayable: [PayableFutureItem]?
  private(set) var budgetExpenses: [String: [ExpenseWithTags]] = [:]

  func invalidate(_ keys: Set<ResourceKey>) {
    cancelInFlightTasks(for: keys)
    invalidatedKeys.formUnion(keys)
    for key in keys {
      switch key {
      case .settings: settings = nil
      case .moneyContext: moneyContext = nil
      case .expenses: expenses = nil
      case .recurringExpenses: recurringExpenses = nil
      case .plannedExpenses: plannedExpenses = nil
      case .budgets: budgets = nil
      case .income: income = nil
      case .schedules: schedules = nil
      case .projections: projections = nil
      case .tags: tags = nil
      case .expensePeriodView(let period):
        expensePeriodViews.removeValue(forKey: period)
      case .upcomingPayable:
        upcomingPayable = nil
      case .budgetExpenses(let id):
        budgetExpenses.removeValue(forKey: id)
      }
    }
  }

  func invalidateAll() {
    cancelInFlightTasks()
    invalidatedKeys = Set(ResourceKey.allBaseKeys)
    settings = nil
    moneyContext = nil
    expenses = nil
    recurringExpenses = nil
    plannedExpenses = nil
    budgets = nil
    income = nil
    schedules = nil
    projections = nil
    tags = nil
    expensePeriodViews = [:]
    upcomingPayable = nil
    budgetExpenses = [:]
  }

  func invalidateAfter(_ event: InvalidationEvent) {
    invalidate(InvalidationMap.keys(for: event))
  }

  private func cancelInFlightTasks(for keys: Set<ResourceKey>? = nil) {
    if let keys {
      for key in keys {
        inFlightTasks[key]?.cancel()
        inFlightTasks.removeValue(forKey: key)
      }
    } else {
      for task in inFlightTasks.values {
        task.cancel()
      }
      inFlightTasks.removeAll()
    }
  }

  private func isInvalidated(_ key: ResourceKey) -> Bool {
    invalidatedKeys.contains(key)
  }

  private func markFresh(_ key: ResourceKey) {
    invalidatedKeys.remove(key)
  }

  func getSettings(fetch: @escaping () async throws -> UserSettings) async throws -> UserSettings {
    try await get(.settings, cached: settings, assign: { self.settings = $0 }, fetch: fetch)
  }

  func getMoneyContext(fetch: @escaping () async throws -> MoneyContextResponse) async throws -> MoneyContextResponse {
    try await get(.moneyContext, cached: moneyContext, assign: { self.moneyContext = $0 }, fetch: fetch)
  }

  func getExpenses(fetch: @escaping () async throws -> [ExpenseWithTags]) async throws -> [ExpenseWithTags] {
    try await get(.expenses, cached: expenses, assign: { self.expenses = $0 }, fetch: fetch)
  }

  func getRecurringExpenses(fetch: @escaping () async throws -> [RecurringExpenseWithTags]) async throws -> [RecurringExpenseWithTags] {
    try await get(.recurringExpenses, cached: recurringExpenses, assign: { self.recurringExpenses = $0 }, fetch: fetch)
  }

  func getPlannedExpenses(fetch: @escaping () async throws -> [PlannedExpenseWithTags]) async throws -> [PlannedExpenseWithTags] {
    try await get(.plannedExpenses, cached: plannedExpenses, assign: { self.plannedExpenses = $0 }, fetch: fetch)
  }

  func getBudgets(fetch: @escaping () async throws -> [BudgetWithTags]) async throws -> [BudgetWithTags] {
    try await get(.budgets, cached: budgets, assign: { self.budgets = $0 }, fetch: fetch)
  }

  func getIncome(fetch: @escaping () async throws -> [Income]) async throws -> [Income] {
    try await get(.income, cached: income, assign: { self.income = $0 }, fetch: fetch)
  }

  func getSchedules(fetch: @escaping () async throws -> [IncomePaySchedule]) async throws -> [IncomePaySchedule] {
    try await get(.schedules, cached: schedules, assign: { self.schedules = $0 }, fetch: fetch)
  }

  func getProjections(fetch: @escaping () async throws -> ProjectionsResponse) async throws -> ProjectionsResponse {
    try await get(.projections, cached: projections, assign: { self.projections = $0 }, fetch: fetch)
  }

  func getTags(fetch: @escaping () async throws -> [String]) async throws -> [String] {
    try await get(.tags, cached: tags, assign: { self.tags = $0 }, fetch: fetch)
  }

  func getExpensePeriodView(
    period: String,
    fetch: @escaping () async throws -> ExpensePeriodViewResponse
  ) async throws -> ExpensePeriodViewResponse {
    let key = ResourceKey.expensePeriodView(period)
    return try await get(key, cached: expensePeriodViews[period], assign: { self.expensePeriodViews[period] = $0 }, fetch: fetch)
  }

  func getUpcomingPayable(
    horizonDays: Int,
    fetch: @escaping () async throws -> [PayableFutureItem]
  ) async throws -> [PayableFutureItem] {
    let key = ResourceKey.upcomingPayable(horizonDays)
    return try await get(key, cached: upcomingPayable, assign: { self.upcomingPayable = $0 }, fetch: fetch)
  }

  func getBudgetExpenses(
    budgetId: String,
    fetch: @escaping () async throws -> [ExpenseWithTags]
  ) async throws -> [ExpenseWithTags] {
    let key = ResourceKey.budgetExpenses(budgetId)
    return try await get(key, cached: budgetExpenses[budgetId], assign: { self.budgetExpenses[budgetId] = $0 }, fetch: fetch)
  }

  private func get<T>(
    _ key: ResourceKey,
    cached: T?,
    assign: @escaping @MainActor (T) -> Void,
    fetch: @escaping () async throws -> T
  ) async throws -> T {
    if !isInvalidated(key), let cached {
      return cached
    }

    if let existing = inFlightTasks[key] {
      return try await existing.value as! T
    }

    let task = Task<Any, Error> { @MainActor in
      let value = try await fetch()
      assign(value)
      markFresh(key)
      return value
    }
    inFlightTasks[key] = task
    defer { inFlightTasks.removeValue(forKey: key) }

    return try await task.value as! T
  }
}
