import Foundation
import Observation

@Observable
@MainActor
final class IncomeViewModel {
  private let deps: AppDependencies

  var section: IncomeSection = .schedules
  var schedules: [IncomePaySchedule] = []
  var incomeEntries: [Income] = []
  var displayedEntries: [Income] = []
  var isLoading = false
  var errorMessage: String?

  var scheduleSheet: IncomePaySchedule?
  var showScheduleForm = false
  var incomeSheet: Income?
  var showIncomeForm = false
  var deleteScheduleTarget: IncomePaySchedule?
  var deleteIncomeTarget: Income?

  init(deps: AppDependencies) {
    self.deps = deps
  }

  var totalIncome: Int {
    displayedEntries.reduce(0) { partial, entry in
      partial + CurrencyConverter.convert(
        amountMinor: entry.amount,
        from: entry.currency,
        to: deps.displayCurrency,
        rates: deps.rates ?? ExchangeRates(base: "USD", rates: [:], fetchedAt: "")
      )
    }
  }

  func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await deps.refreshSharedContext()
      async let schedulesTask = deps.api.getIncomeSchedules()
      async let incomeTask = deps.api.getIncome()
      schedules = try await schedulesTask
      incomeEntries = try await incomeTask
      refreshDisplayedEntries()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func refreshDisplayedEntries() {
    displayedEntries = IncomeFilterLogic.filterEntriesForDisplay(entries: incomeEntries, schedules: schedules)
  }

  func deleteSchedule(_ schedule: IncomePaySchedule) async {
    do {
      try await deps.api.deleteIncomeSchedule(id: schedule.id)
      Haptics.light()
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func deleteIncome(_ income: Income) async {
    do {
      try await deps.api.deleteIncome(id: income.id)
      Haptics.light()
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

@Observable
@MainActor
final class IncomeScheduleFormModel {
  var name = ""
  var anchorDate = PayPeriodLogic.todayISO()
  var frequency: PayFrequency = .biweekly
  var amountText = ""
  var currency: CurrencyCode = .eur

  private let editing: IncomePaySchedule?
  private let deps: AppDependencies

  var isEditing: Bool { editing != nil }

  init(deps: AppDependencies, editing: IncomePaySchedule? = nil) {
    self.deps = deps
    self.editing = editing
    if let editing {
      name = editing.name
      anchorDate = editing.anchorDate
      frequency = editing.frequency
      amountText = String(editing.amount)
      currency = editing.currency
    } else {
      currency = deps.displayCurrency
    }
  }

  var canSave: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty && amountMinor != nil
  }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency) ?? Int(amountText)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    let body = CreateIncomeScheduleRequest(
      name: name.trimmingCharacters(in: .whitespaces),
      anchorDate: anchorDate,
      frequency: frequency,
      amount: amount,
      currency: currency
    )
    if let editing {
      _ = try await deps.api.updateIncomeSchedule(id: editing.id, body)
    } else {
      _ = try await deps.api.createIncomeSchedule(body)
    }
  }
}

@Observable
@MainActor
final class IncomeEntryFormModel {
  var name = ""
  var date = PayPeriodLogic.todayISO()
  var amountText = ""
  var currency: CurrencyCode = .eur

  private let editing: Income?
  private let deps: AppDependencies

  var isEditing: Bool { editing != nil }

  init(deps: AppDependencies, editing: Income? = nil) {
    self.deps = deps
    self.editing = editing
    if let editing {
      name = editing.name
      date = editing.date
      amountText = String(editing.amount)
      currency = editing.currency
    } else {
      currency = deps.displayCurrency
    }
  }

  var canSave: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty && amountMinor != nil
  }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency) ?? Int(amountText)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    let body = CreateIncomeRequest(
      name: name.trimmingCharacters(in: .whitespaces),
      amount: amount,
      currency: currency,
      date: date
    )
    if let editing {
      _ = try await deps.api.updateIncome(id: editing.id, body)
    } else {
      _ = try await deps.api.createIncome(body)
    }
  }
}
