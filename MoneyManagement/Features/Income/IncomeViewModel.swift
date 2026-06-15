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
  var isLoadingSchedules = false
  var isLoadingEntries = false
  var errorMessage: String?

  var scheduleSheet: IncomePaySchedule?
  var showScheduleForm = false
  var incomeSheet: Income?
  var showIncomeForm = false
  var amountEditEntry: Income?
  var showAmountForm = false
  var deleteScheduleTarget: IncomePaySchedule?
  var deleteIncomeTarget: Income?

  private var loadGeneration = LoadGeneration()

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

  func load(force: Bool = false) async {
    let token = loadGeneration.next()
    errorMessage = nil
    isLoadingSchedules = true
    isLoadingEntries = true
    defer {
      if loadGeneration.isCurrent(token) {
        isLoadingSchedules = false
        isLoadingEntries = false
      }
    }

    if force {
      deps.invalidateAll()
    }

    do {
      try await deps.refreshSharedContext()
      guard loadGeneration.isCurrent(token) else { return }
      async let schedulesTask: Void = loadSchedules(loadToken: token)
      async let entriesTask: Void = loadEntries(loadToken: token)
      _ = await (schedulesTask, entriesTask)
    } catch {
      guard shouldSurfaceLoadError(error, isCurrent: loadGeneration.isCurrent(token)) else { return }
      errorMessage = error.localizedDescription
    }
  }

  func loadSchedules(loadToken: Int? = nil) async {
    let managesLoading = loadToken == nil
    if managesLoading {
      isLoadingSchedules = true
    }
    defer {
      if managesLoading {
        isLoadingSchedules = false
      }
    }

    do {
      schedules = try await deps.dataStore.getSchedules { [deps] in
        try await deps.api.getIncomeSchedules()
      }
    } catch {
      if let loadToken, !loadGeneration.isCurrent(loadToken) { return }
      if !shouldSurfaceLoadError(error, isCurrent: true) { return }
      errorMessage = error.localizedDescription
    }
  }

  func loadEntries(loadToken: Int? = nil) async {
    let managesLoading = loadToken == nil
    if managesLoading {
      isLoadingEntries = true
    }
    defer {
      if managesLoading {
        isLoadingEntries = false
      }
    }

    do {
      incomeEntries = try await deps.dataStore.getIncome { [deps] in
        try await deps.api.getIncome()
      }
      refreshDisplayedEntries()
    } catch {
      if let loadToken, !loadGeneration.isCurrent(loadToken) { return }
      if !shouldSurfaceLoadError(error, isCurrent: true) { return }
      errorMessage = error.localizedDescription
    }
  }

  func refreshDisplayedEntries() {
    displayedEntries = IncomeFilterLogic.filterEntriesForDisplay(entries: incomeEntries)
  }

  func beginEditAmount(_ entry: Income) {
    amountEditEntry = entry
    showAmountForm = true
  }

  func deleteSchedule(_ schedule: IncomePaySchedule) async {
    do {
      try await deps.api.deleteIncomeSchedule(id: schedule.id)
      deps.invalidateAfter(.scheduleChange)
      Haptics.light()
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func deleteIncome(_ income: Income) async {
    do {
      try await deps.api.deleteIncome(id: income.id)
      deps.invalidateAfter(.incomeChange)
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
      amountText = MoneyFormatter.formatMinorUnitsAsInput(editing.amount, currency: editing.currency)
      currency = editing.currency
    } else {
      currency = deps.displayCurrency
    }
  }

  var canSave: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty && amountMinor != nil
  }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency)
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
    deps.invalidateAfter(.scheduleChange)
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
      amountText = MoneyFormatter.formatMinorUnitsAsInput(editing.amount, currency: editing.currency)
      currency = editing.currency
    } else {
      currency = deps.displayCurrency
    }
  }

  var canSave: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty && amountMinor != nil
  }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency)
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
    deps.invalidateAfter(.incomeChange)
  }
}

@Observable
@MainActor
final class IncomeAmountFormModel {
  var amountText = ""

  private let entry: Income
  private let deps: AppDependencies

  init(deps: AppDependencies, entry: Income) {
    self.deps = deps
    self.entry = entry
    amountText = MoneyFormatter.formatMinorUnitsAsInput(entry.amount, currency: entry.currency)
  }

  var canSave: Bool { amountMinor != nil }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: entry.currency)
  }

  // Amount-only override for materialized scheduled income. Schedule-owned name/date/currency
  // are sent unchanged; the API applies just the amount override for scheduled rows.
  func save() async throws {
    guard let amount = amountMinor else { return }
    let body = CreateIncomeRequest(
      name: entry.name,
      amount: amount,
      currency: entry.currency,
      date: entry.date
    )
    _ = try await deps.api.updateIncome(id: entry.id, body)
    deps.invalidateAfter(.incomeChange)
  }
}
