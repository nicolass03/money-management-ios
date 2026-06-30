import Foundation
import Observation

@Observable
@MainActor
final class PlannedExpensesViewModel {
  private let deps: AppDependencies

  var items: [PlannedExpenseWithTags] = []
  var tags: [String] = []
  var isLoading = false
  var errorMessage: String?

  var editing: PlannedExpenseWithTags?
  var showForm = false
  var deleteTarget: PlannedExpenseWithTags?

  init(deps: AppDependencies) {
    self.deps = deps
  }

  var upcomingTotal: Int {
    let today = PayPeriodLogic.todayISO()
    return items.filter { $0.date >= today }.reduce(0) { partial, item in
      partial + CurrencyConverter.convert(
        amountMinor: item.amount,
        from: item.currency,
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
      async let plannedTask = deps.dataStore.getPlannedExpenses { [deps] in
        try await deps.api.getPlannedExpenses()
      }
      async let tagsTask = deps.dataStore.getTags { [deps] in
        try await deps.api.getTags()
      }
      items = try await plannedTask.sorted { $0.date < $1.date }
      tags = try await tagsTask
    } catch {
      guard shouldSurfaceLoadError(error, isCurrent: true) else { return }
      errorMessage = error.localizedDescription
    }
  }

  func delete(_ item: PlannedExpenseWithTags) async {
    do {
      try await deps.api.deletePlannedExpense(id: item.id)
      deps.invalidateAfter(.plannedChange)
      Haptics.light()
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

@Observable
@MainActor
final class PlannedExpenseFormModel {
  var name = ""
  var date = PayPeriodLogic.todayISO()
  var amountText = ""
  var tagsText = ""
  var accounts: [Account] = []
  var accountId: String?

  private let editing: PlannedExpenseWithTags?
  private let deps: AppDependencies

  var isEditing: Bool { editing != nil }

  init(deps: AppDependencies, editing: PlannedExpenseWithTags? = nil) {
    self.deps = deps
    self.editing = editing
    if let editing {
      name = editing.name
      date = editing.date
      amountText = MoneyFormatter.formatMinorUnitsAsInput(editing.amount, currency: editing.currency)
      accountId = editing.accountId
      tagsText = editing.tags.joined(separator: ", ")
    }
  }

  /// Currency follows the selected source account.
  var selectedAccount: Account? {
    accounts.first { $0.id == accountId } ?? accounts.first
  }

  var currency: CurrencyCode {
    selectedAccount?.currency ?? editing?.currency ?? deps.displayCurrency
  }

  func loadAccounts() async {
    accounts = (try? await deps.dataStore.getAccounts { [deps] in try await deps.api.getAccounts() }) ?? []
    if accountId == nil { accountId = accounts.first?.id }
  }

  var canSave: Bool {
    !name.isEmpty && amountMinor != nil && !TagsInputField.parseTags(tagsText).isEmpty
  }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    let body = CreatePlannedExpenseRequest(
      name: name.trimmingCharacters(in: .whitespaces),
      date: date,
      amount: amount,
      currency: currency,
      tags: TagsInputField.parseTags(tagsText),
      accountId: selectedAccount?.id
    )
    if let editing {
      _ = try await deps.api.updatePlannedExpense(id: editing.id, body)
    } else {
      _ = try await deps.api.createPlannedExpense(body)
    }
    deps.invalidateAfter(.plannedChange)
  }
}
