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
  var payTarget: PlannedExpenseWithTags?
  var payAmountText = ""

  init(deps: AppDependencies) {
    self.deps = deps
  }

  var upcomingTotal: Int {
    let today = PayPeriodLogic.todayISO()
    return items.filter { !$0.paid && ($0.date.map { $0 > today } ?? false) }.reduce(0) { partial, item in
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
      // The API orders by date, undated items last.
      items = try await plannedTask
      tags = try await tagsTask
    } catch {
      guard shouldSurfaceLoadError(error, isCurrent: true) else { return }
      errorMessage = error.localizedDescription
    }
  }

  func startPay(_ item: PlannedExpenseWithTags) {
    payAmountText = MoneyFormatter.formatMinorUnitsAsInput(item.amount, currency: item.currency)
    payTarget = item
  }

  /// Records the full payment today for `item`, with the amount from `payAmountText`.
  func pay(_ item: PlannedExpenseWithTags) async {
    guard let amount = MoneyFormatter.parseToMinorUnits(payAmountText, currency: item.currency), amount > 0 else {
      errorMessage = L10n.t("invalid amount")
      return
    }
    do {
      _ = try await deps.api.payPlannedExpense(id: item.id, amount: amount)
      deps.invalidateAfter(.plannedChange)
      Haptics.success()
      await load()
    } catch {
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
  /// Empty = undated (e.g. a debt with no due date).
  var date = ""
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
      date = editing.date ?? ""
      amountText = MoneyFormatter.formatMinorUnitsAsInput(editing.amount, currency: editing.currency)
      accountId = editing.accountId
      tagsText = editing.tags.joined(separator: ", ")
    }
  }

  /// Currency follows the selected source account. When editing a planned expense whose account
  /// was archived (absent from `accounts`), this stays nil rather than silently falling back to
  /// the first account — save() then preserves the row's own account id and currency instead of
  /// reassigning it. New rows default to the first account.
  var selectedAccount: Account? {
    if let match = accounts.first(where: { $0.id == accountId }) { return match }
    return isEditing ? nil : accounts.first
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
    let trimmedDate = date.trimmingCharacters(in: .whitespaces)
    let body = CreatePlannedExpenseRequest(
      name: name.trimmingCharacters(in: .whitespaces),
      date: trimmedDate.isEmpty ? nil : trimmedDate,
      amount: amount,
      currency: currency,
      tags: TagsInputField.parseTags(tagsText),
      accountId: selectedAccount?.id ?? accountId
    )
    if let editing {
      _ = try await deps.api.updatePlannedExpense(id: editing.id, body)
    } else {
      _ = try await deps.api.createPlannedExpense(body)
    }
    deps.invalidateAfter(.plannedChange)
  }
}
