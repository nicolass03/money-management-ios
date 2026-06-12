import Foundation
import Observation

@Observable
@MainActor
final class BudgetsViewModel {
  private let deps: AppDependencies

  var budgets: [BudgetWithTags] = []
  var groupedBudgets: [(BudgetStatus, [BudgetWithTags])] = []
  var expandedBudgetIds: Set<String> = []
  var budgetExpenses: [String: [ExpenseWithTags]] = [:]
  var loadingExpenses: Set<String> = []
  var isLoading = false
  var errorMessage: String?

  var editingBudget: BudgetWithTags?
  var showBudgetForm = false
  var expenseBudgetId: String?
  var showExpenseForm = false
  var deleteBudgetTarget: BudgetWithTags?
  var deleteExpenseTarget: (budgetId: String, expense: ExpenseWithTags)?

  init(deps: AppDependencies) {
    self.deps = deps
  }

  var totalAllocated: Int {
    budgets.reduce(0) { partial, budget in
      partial + CurrencyConverter.convert(
        amountMinor: budget.amount,
        from: budget.currency,
        to: deps.displayCurrency,
        rates: deps.rates ?? ExchangeRates(base: "USD", rates: [:], fetchedAt: "")
      )
    }
  }

  func load(force: Bool = false) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      if force {
        deps.invalidateAll()
      }

      try await deps.refreshSharedContext()
      budgets = try await deps.dataStore.getBudgets { [deps] in
        try await deps.api.getBudgets()
      }
      groupedBudgets = BudgetStatusLogic.grouped(budgets)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func toggleExpanded(_ budget: BudgetWithTags) async {
    if expandedBudgetIds.contains(budget.id) {
      expandedBudgetIds.remove(budget.id)
      return
    }
    expandedBudgetIds.insert(budget.id)
    if budgetExpenses[budget.id] == nil {
      await loadExpenses(for: budget.id)
    }
  }

  func loadExpenses(for budgetId: String) async {
    loadingExpenses.insert(budgetId)
    defer { loadingExpenses.remove(budgetId) }

    do {
      budgetExpenses[budgetId] = try await deps.dataStore.getBudgetExpenses(budgetId: budgetId) { [deps] in
        try await deps.api.getBudgetExpenses(budgetId: budgetId)
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func deleteBudget(_ budget: BudgetWithTags) async {
    do {
      try await deps.api.deleteBudget(id: budget.id)
      deps.invalidateAfter(.budgetChange)
      expandedBudgetIds.remove(budget.id)
      budgetExpenses.removeValue(forKey: budget.id)
      Haptics.light()
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func deleteBudgetExpense(budgetId: String, expense: ExpenseWithTags) async {
    do {
      try await deps.api.deleteBudgetExpense(budgetId: budgetId, expenseId: expense.id)
      deps.invalidateAfter(.budgetChange)
      deps.dataStore.invalidate([.budgetExpenses(budgetId)])
      Haptics.light()
      await loadExpenses(for: budgetId)
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

@Observable
@MainActor
final class BudgetFormModel {
  var name = ""
  var amountText = ""
  var currency: CurrencyCode = .eur
  var startDate = ""
  var endDate = ""
  var tagsText = ""

  private let editing: BudgetWithTags?
  private let deps: AppDependencies

  var isEditing: Bool { editing != nil }

  init(deps: AppDependencies, editing: BudgetWithTags? = nil) {
    self.deps = deps
    self.editing = editing
    if let editing {
      name = editing.name
      amountText = String(editing.amount)
      currency = editing.currency
      startDate = editing.startDate ?? ""
      endDate = editing.endDate ?? ""
      tagsText = editing.tags.joined(separator: ", ")
    } else {
      currency = deps.displayCurrency
    }
  }

  var canSave: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty && amountMinor != nil && !parsedTags.isEmpty
  }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency) ?? Int(amountText)
  }

  var parsedTags: [String] {
    TagsInputField.parseTags(tagsText)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    let body = CreateBudgetRequest(
      name: name.trimmingCharacters(in: .whitespaces),
      amount: amount,
      currency: currency,
      startDate: startDate.isEmpty ? nil : startDate,
      endDate: endDate.isEmpty ? nil : endDate,
      tags: parsedTags
    )
    if let editing {
      _ = try await deps.api.updateBudget(id: editing.id, body)
    } else {
      _ = try await deps.api.createBudget(body)
    }
    deps.invalidateAfter(.budgetChange)
  }
}

@Observable
@MainActor
final class BudgetExpenseFormModel {
  var name = ""
  var amountText = ""
  var date = PayPeriodLogic.todayISO()

  private let budget: BudgetWithTags
  private let deps: AppDependencies

  init(deps: AppDependencies, budget: BudgetWithTags) {
    self.deps = deps
    self.budget = budget
    name = budget.name
  }

  var canSave: Bool { amountMinor != nil }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: budget.currency) ?? Int(amountText)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    let body = CreateBudgetExpenseRequest(
      name: name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name.trimmingCharacters(in: .whitespaces),
      amount: amount,
      date: date
    )
    _ = try await deps.api.createBudgetExpense(budgetId: budget.id, body)
    deps.invalidateAfter(.budgetChange)
    deps.dataStore.invalidate([.budgetExpenses(budget.id)])
  }
}
