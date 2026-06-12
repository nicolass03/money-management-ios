import Foundation
import Observation

@Observable
@MainActor
final class ExpensesViewModel {
  private let deps: AppDependencies

  var periodKey: ExpensePeriodKey = .lastPeriod
  var expenses: [ExpenseWithTags] = []
  var recurring: [RecurringExpenseWithTags] = []
  var planned: [PlannedExpenseWithTags] = []
  var budgets: [BudgetWithTags] = []
  var tags: [String] = []
  var primarySchedule: IncomePaySchedule?

  var isLoading = false
  var errorMessage: String?

  var showExpenseForm = false
  var editingExpense: ExpenseWithTags?
  var editAmountExpense: ExpenseWithTags?
  var showEditAmountForm = false
  var deleteExpenseTarget: ExpenseWithTags?

  init(deps: AppDependencies) {
    self.deps = deps
  }

  var needsPrimarySchedule: Bool {
    periodKey == .lastPeriod && deps.settings?.primaryScheduleId == nil
  }

  var actualPeriodExpenses: [ExpenseWithTags] {
    ExpensePeriodFilter.filterExpenses(
      expenses,
      periodKey: periodKey,
      primarySchedule: primarySchedule
    )
  }

  var periodItems: [ProjectionExpenseItem] {
    guard ExpensePeriodFilter.resolvePeriodDates(
      periodKey: periodKey,
      primarySchedule: primarySchedule
    ) != nil else { return [] }

    return mapActualExpensesToItems(actualPeriodExpenses)
  }

  private func mapActualExpensesToItems(_ expenses: [ExpenseWithTags]) -> [ProjectionExpenseItem] {
    let rates = deps.rates ?? ExchangeRates(base: "USD", rates: [:], fetchedAt: "")
    return expenses
      .sorted { $0.date < $1.date }
      .map { expense in
        ProjectionExpenseItem(
          itemId: expense.id,
          recurringId: expense.recurringId,
          plannedExpenseId: expense.plannedExpenseId,
          budgetId: expense.budgetId,
          budgetTotal: nil,
          budgetSpent: nil,
          isBudgetSummary: nil,
          name: expense.name,
          date: expense.date,
          scheduledDate: expense.scheduledDate,
          amount: expense.amount,
          currency: expense.currency,
          originalAmount: nil,
          originalCurrency: nil,
          convertedAmount: CurrencyConverter.convert(
            amountMinor: expense.amount,
            from: expense.currency,
            to: deps.displayCurrency,
            rates: rates
          ),
          tags: expense.tags,
          isSubscription: expense.isSubscription,
          projected: false
        )
      }
  }

  var totalSpend: Int {
    let rates = deps.rates ?? ExchangeRates(base: "USD", rates: [:], fetchedAt: "")
    return actualPeriodExpenses.reduce(0) { partial, expense in
      partial + CurrencyConverter.convert(
        amountMinor: expense.amount,
        from: expense.currency,
        to: deps.displayCurrency,
        rates: rates
      )
    }
  }

  var subscriptionShareLabel: String {
    let subs = actualPeriodExpenses.filter(\.isSubscription)
    guard !actualPeriodExpenses.isEmpty else { return "subscriptions: 0%" }
    let pct = Int((Double(subs.count) / Double(actualPeriodExpenses.count) * 100).rounded())
    return "subscriptions: \(pct)%"
  }

  var topTagLabel: String {
    var counts: [String: Int] = [:]
    for expense in actualPeriodExpenses {
      for tag in expense.tags {
        counts[tag, default: 0] += 1
      }
    }
    guard let top = counts.max(by: { $0.value < $1.value }) else { return "top spending: —" }
    return "top spending: \(top.key)"
  }

  var periodSubtitle: String? {
    guard let period = ExpensePeriodFilter.resolvePeriodDates(periodKey: periodKey, primarySchedule: primarySchedule) else {
      return nil
    }
    return "\(period.startDate) → \(period.endDate)"
  }

  func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await deps.refreshSharedContext()

      if let scheduleId = deps.settings?.primaryScheduleId {
        primarySchedule = try? await deps.api.getIncomeSchedule(id: scheduleId)
      } else {
        primarySchedule = nil
      }

      async let expensesTask = deps.api.getExpenses()
      async let recurringTask = deps.api.getRecurringExpenses()
      async let plannedTask = deps.api.getPlannedExpenses()
      async let budgetsTask = deps.api.getBudgets()
      async let tagsTask = deps.api.getTags()

      expenses = try await expensesTask
      recurring = try await recurringTask
      planned = try await plannedTask
      budgets = try await budgetsTask
      tags = try await tagsTask
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func deleteExpense(_ expense: ExpenseWithTags) async {
    do {
      try await deps.api.deleteExpense(id: expense.id)
      Haptics.light()
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func canEdit(_ item: ProjectionExpenseItem) -> Bool {
    guard let id = item.itemId,
          let expense = expenses.first(where: { $0.id == id }) else { return false }
    return !expense.isSystemGenerated || (expense.recurringId == nil && expense.plannedExpenseId == nil && expense.budgetId == nil)
  }

  func canDelete(_ item: ProjectionExpenseItem) -> Bool {
    guard let id = item.itemId,
          let expense = expenses.first(where: { $0.id == id }) else { return false }
    return !expense.isSystemGenerated
  }

  func expenseForItem(_ item: ProjectionExpenseItem) -> ExpenseWithTags? {
    guard let id = item.itemId else { return nil }
    return expenses.first { $0.id == id }
  }
}

@Observable
@MainActor
final class ExpenseFormModel {
  var name = ""
  var amountText = ""
  var currency: CurrencyCode = .eur
  var date = PayPeriodLogic.todayISO()
  var tagsText = ""
  var isSubscription = false

  private let deps: AppDependencies

  init(deps: AppDependencies) {
    self.deps = deps
    currency = deps.displayCurrency
  }

  var canSave: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty && amountMinor != nil && !TagsInputField.parseTags(tagsText).isEmpty
  }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency) ?? Int(amountText)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    let body = CreateExpenseRequest(
      name: name.trimmingCharacters(in: .whitespaces),
      amount: amount,
      currency: currency,
      date: date,
      tags: TagsInputField.parseTags(tagsText),
      isSubscription: isSubscription
    )
    _ = try await deps.api.createExpense(body)
  }
}

@Observable
@MainActor
final class ExpenseAmountFormModel {
  var amountText = ""
  private let expense: ExpenseWithTags
  private let deps: AppDependencies

  init(deps: AppDependencies, expense: ExpenseWithTags) {
    self.deps = deps
    self.expense = expense
    amountText = String(expense.amount)
  }

  var canSave: Bool { amountMinor != nil }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: expense.currency) ?? Int(amountText)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    _ = try await deps.api.updateExpenseAmount(id: expense.id, amount: amount)
  }
}

@Observable
@MainActor
final class EarlyPayFormModel {
  var paidDate = PayPeriodLogic.todayISO()
  var amountText = ""

  private let item: PayableFutureItem
  private let deps: AppDependencies

  init(deps: AppDependencies, item: PayableFutureItem) {
    self.deps = deps
    self.item = item
    amountText = String(item.amount)
  }

  var canSave: Bool { amountMinor != nil }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: item.currency) ?? Int(amountText)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    let body = EarlyPayExpenseRequest(
      sourceType: item.sourceType,
      scheduledDate: item.scheduledDate,
      paidDate: paidDate,
      amount: amount,
      currency: item.currency,
      recurringId: item.recurringId,
      plannedExpenseId: item.plannedExpenseId
    )
    _ = try await deps.api.earlyPayExpense(body)
  }
}
