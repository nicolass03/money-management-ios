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
  var currency: CurrencyCode = .eur
  var tagsText = ""

  private let editing: PlannedExpenseWithTags?
  private let deps: AppDependencies

  var isEditing: Bool { editing != nil }

  init(deps: AppDependencies, editing: PlannedExpenseWithTags? = nil) {
    self.deps = deps
    self.editing = editing
    if let editing {
      name = editing.name
      date = editing.date
      amountText = String(editing.amount)
      currency = editing.currency
      tagsText = editing.tags.joined(separator: ", ")
    } else {
      currency = deps.displayCurrency
    }
  }

  var canSave: Bool {
    !name.isEmpty && amountMinor != nil && !TagsInputField.parseTags(tagsText).isEmpty
  }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency) ?? Int(amountText)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    let body = CreatePlannedExpenseRequest(
      name: name.trimmingCharacters(in: .whitespaces),
      date: date,
      amount: amount,
      currency: currency,
      tags: TagsInputField.parseTags(tagsText)
    )
    if let editing {
      _ = try await deps.api.updatePlannedExpense(id: editing.id, body)
    } else {
      _ = try await deps.api.createPlannedExpense(body)
    }
    deps.invalidateAfter(.plannedChange)
  }
}
