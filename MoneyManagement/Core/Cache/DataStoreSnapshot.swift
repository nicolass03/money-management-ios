import Foundation

/// Codable mirror of `DataStore`'s cached resources, persisted to disk so a cold launch can paint
/// the last-known data instantly while the live values revalidate in the background
/// (stale-while-revalidate).
///
/// Every field is optional: `nil` means "absent from this partial snapshot" and is treated as
/// "keep whatever is already persisted" when merging — so persisting after a single resource fetch
/// never wipes the others.
struct DataStoreSnapshot: Codable {
  var userID: String?
  var settings: UserSettings?
  var moneyContext: MoneyContextResponse?
  var expenses: [ExpenseWithTags]?
  var recurringExpenses: [RecurringExpenseWithTags]?
  var plannedExpenses: [PlannedExpenseWithTags]?
  var budgets: [BudgetWithTags]?
  var income: [Income]?
  var schedules: [IncomePaySchedule]?
  var projections: ProjectionsResponse?
  var tags: [String]?
  var expensePeriodViews: [String: ExpensePeriodViewResponse]?
  var upcomingPayable: [PayableFutureItem]?

  /// Returns a snapshot with `other`'s non-nil fields layered over this one (dictionaries merged
  /// entry-by-entry, newest wins). Lets each persist call update only the resources it knows about.
  func merging(_ other: DataStoreSnapshot) -> DataStoreSnapshot {
    var result = self
    if let value = other.userID { result.userID = value }
    if let value = other.settings { result.settings = value }
    if let value = other.moneyContext { result.moneyContext = value }
    if let value = other.expenses { result.expenses = value }
    if let value = other.recurringExpenses { result.recurringExpenses = value }
    if let value = other.plannedExpenses { result.plannedExpenses = value }
    if let value = other.budgets { result.budgets = value }
    if let value = other.income { result.income = value }
    if let value = other.schedules { result.schedules = value }
    if let value = other.projections { result.projections = value }
    if let value = other.tags { result.tags = value }
    if let value = other.expensePeriodViews {
      result.expensePeriodViews = (result.expensePeriodViews ?? [:]).merging(value) { _, new in new }
    }
    if let value = other.upcomingPayable { result.upcomingPayable = value }
    return result
  }
}
