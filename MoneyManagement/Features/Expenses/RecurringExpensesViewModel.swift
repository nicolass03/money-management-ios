import Foundation
import Observation

@Observable
@MainActor
final class RecurringExpensesViewModel {
  private let deps: AppDependencies

  var items: [RecurringExpenseWithTags] = []
  var tags: [String] = []
  var isLoading = false
  var errorMessage: String?

  var editing: RecurringExpenseWithTags?
  var showForm = false
  var deleteTarget: RecurringExpenseWithTags?
  var showCancelReminderSheet = false

  var subscriptions: [RecurringExpenseWithTags] {
    items.filter(\.isSubscription)
  }

  init(deps: AppDependencies) {
    self.deps = deps
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
      async let recurringTask = deps.dataStore.getRecurringExpenses { [deps] in
        try await deps.api.getRecurringExpenses()
      }
      async let tagsTask = deps.dataStore.getTags { [deps] in
        try await deps.api.getTags()
      }
      items = try await recurringTask
      tags = try await tagsTask
    } catch {
      guard shouldSurfaceLoadError(error, isCurrent: true) else { return }
      errorMessage = error.localizedDescription
    }
  }

  func delete(_ item: RecurringExpenseWithTags) async {
    do {
      try await deps.api.deleteRecurringExpense(id: item.id)
      deps.invalidateAfter(.recurringChange)
      Haptics.light()
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func setCancelReminder(_ item: RecurringExpenseWithTags, enabled: Bool) async {
    do {
      if enabled {
        _ = try await deps.api.setCancelReminder(id: item.id)
      } else {
        try await deps.api.clearCancelReminder(id: item.id)
      }
      deps.invalidateAfter(.recurringChange)
      Haptics.light()
      await load()
      await deps.refreshSubscriptionReminders()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

@Observable
@MainActor
final class RecurringExpenseFormModel {
  var name = ""
  var anchorDate = PayPeriodLogic.todayISO()
  var frequency: PayFrequency = .monthly
  var amountText = ""
  var currency: CurrencyCode = .eur
  var tagsText = ""
  var isSubscription = false
  var lastPaymentDate = ""

  private let editing: RecurringExpenseWithTags?
  private let deps: AppDependencies

  var isEditing: Bool { editing != nil }

  init(deps: AppDependencies, editing: RecurringExpenseWithTags? = nil) {
    self.deps = deps
    self.editing = editing
    if let editing {
      name = editing.name
      anchorDate = editing.anchorDate
      frequency = editing.frequency
      amountText = MoneyFormatter.formatMinorUnitsAsInput(editing.amount, currency: editing.currency)
      currency = editing.currency
      tagsText = editing.tags.joined(separator: ", ")
      isSubscription = editing.isSubscription
      lastPaymentDate = editing.lastPaymentDate ?? ""
    } else {
      currency = deps.displayCurrency
    }
  }

  var canSave: Bool {
    !name.isEmpty && amountMinor != nil && !TagsInputField.parseTags(tagsText).isEmpty
  }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    let body = CreateRecurringExpenseRequest(
      name: name.trimmingCharacters(in: .whitespaces),
      anchorDate: anchorDate,
      frequency: frequency,
      amount: amount,
      currency: currency,
      tags: TagsInputField.parseTags(tagsText),
      isSubscription: isSubscription,
      lastPaymentDate: lastPaymentDate.isEmpty ? nil : lastPaymentDate
    )
    if let editing {
      _ = try await deps.api.updateRecurringExpense(id: editing.id, body)
    } else {
      _ = try await deps.api.createRecurringExpense(body)
    }
    deps.invalidateAfter(.recurringChange)
  }
}
