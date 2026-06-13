import Foundation
import Observation

@Observable
@MainActor
final class ExpensesViewModel {
  private let deps: AppDependencies

  var periodKey: ExpensePeriodKey = .lastPeriod {
    didSet {
      if oldValue != periodKey {
        Task { await loadPeriod() }
      }
    }
  }

  var periodView: ExpensePeriodViewResponse?
  var upcomingPayable: [PayableFutureItem] = []
  var formTags: [String] = []

  var isLoadingPeriod = false
  var isLoadingUpcoming = false
  var errorMessage: String?

  var showExpenseForm = false
  var editAmountExpenseId: String?
  var editAmountInitial: Int?
  var editAmountCurrency: CurrencyCode?
  var showEditAmountForm = false
  var deleteExpenseId: String?

  private var loadGeneration = LoadGeneration()

  init(deps: AppDependencies) {
    self.deps = deps
  }

  var primarySchedule: IncomePaySchedule? {
    deps.settings?.primarySchedule
  }

  var needsPrimarySchedule: Bool {
    guard periodKey == .lastPeriod, let settings = deps.settings else { return false }
    return settings.primaryScheduleId == nil
  }

  var isLoadingSharedContext: Bool {
    deps.isLoadingContext
  }

  var periodItems: [ProjectionExpenseItem] {
    periodView?.items ?? []
  }

  var totalSpend: Int {
    periodView?.totalSpend ?? 0
  }

  var periodSubtitle: String? {
    if let period = periodView?.period {
      return "\(period.startDate) → \(period.endDate)"
    }
    guard let period = ExpensePeriodFilter.resolvePeriodDates(
      periodKey: periodKey,
      primarySchedule: primarySchedule
    ) else {
      return nil
    }
    return "\(period.startDate) → \(period.endDate)"
  }

  func load(force: Bool = false) async {
    let token = loadGeneration.next()
    errorMessage = nil
    if force {
      deps.invalidateAll()
    }

    // Fire shared context (settings + money-context) alongside the section fetches rather than
    // before them: `period-view` and `upcoming-payable` are resolved server-side from the user's
    // schedule and don't need settings to be issued. Awaiting context first only added a round-trip
    // to the skeleton time — costly on high-latency mobile connections.
    async let contextTask: Void = loadSharedContext(loadToken: token)
    async let periodTask: Void = loadPeriod(loadToken: token)
    async let upcomingTask: Void = loadUpcoming(loadToken: token)
    _ = await (contextTask, periodTask, upcomingTask)
  }

  private func loadSharedContext(loadToken: Int) async {
    do {
      try await deps.refreshSharedContext()
    } catch {
      guard shouldSurfaceLoadError(error, isCurrent: loadGeneration.isCurrent(loadToken)) else { return }
      errorMessage = error.localizedDescription
    }
  }

  func loadPeriod(loadToken: Int? = nil) async {
    isLoadingPeriod = true
    defer { isLoadingPeriod = false }

    let key = periodKey
    do {
      let view = try await deps.dataStore.getExpensePeriodView(period: key.rawValue) { [deps] in
        try await deps.api.getExpensePeriodView(period: key)
      }
      // The `periodKey` didSet spawns loads without a generation token, so a slower fetch
      // for a period the user already toggled away from must not overwrite the current view.
      guard key == periodKey else { return }
      if let loadToken, !loadGeneration.isCurrent(loadToken) { return }
      periodView = view
    } catch {
      guard key == periodKey else { return }
      if let loadToken, !loadGeneration.isCurrent(loadToken) { return }
      if !shouldSurfaceLoadError(error, isCurrent: true) { return }
      // Context now loads in parallel, so settings may not be resolved yet. Resolve it (coalesced
      // with the in-flight shared-context load — no extra request) so a missing primary schedule is
      // shown as an empty state rather than a spurious error.
      if deps.settings == nil {
        try? await deps.refreshSharedContext()
      }
      if periodKey == .lastPeriod, deps.settings?.primaryScheduleId == nil {
        periodView = nil
      } else {
        errorMessage = error.localizedDescription
      }
    }
  }

  func loadUpcoming(loadToken: Int? = nil) async {
    isLoadingUpcoming = true
    defer { isLoadingUpcoming = false }

    do {
      let horizon = ExpenseDefaults.upcomingPayableHorizonDays
      upcomingPayable = try await deps.dataStore.getUpcomingPayable(horizonDays: horizon) { [deps] in
        try await deps.api.getUpcomingPayable(horizonDays: horizon)
      }
    } catch {
      if let loadToken, !loadGeneration.isCurrent(loadToken) { return }
      if !shouldSurfaceLoadError(error, isCurrent: true) { return }
      errorMessage = error.localizedDescription
    }
  }

  func loadFormTags() async {
    do {
      formTags = try await deps.dataStore.getTags { [deps] in
        try await deps.api.getTags()
      }
    } catch {
      formTags = []
    }
  }

  func deleteExpense(id: String) async {
    do {
      try await deps.api.deleteExpense(id: id)
      deps.invalidateAfter(.expenseChange)
      Haptics.light()
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func canEdit(_ item: ProjectionExpenseItem) -> Bool {
    item.itemId != nil && !item.projected && item.isBudgetSummary != true
  }

  func canDelete(_ item: ProjectionExpenseItem) -> Bool {
    guard canEdit(item) else { return false }
    return item.recurringId == nil && item.plannedExpenseId == nil && item.budgetId == nil
  }

  func beginEditAmount(for item: ProjectionExpenseItem) {
    guard let id = item.itemId else { return }
    editAmountExpenseId = id
    editAmountInitial = item.amount
    editAmountCurrency = item.currency
    showEditAmountForm = true
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
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency)
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
    deps.invalidateAfter(.expenseChange)
  }
}

@Observable
@MainActor
final class ExpenseAmountFormModel {
  var amountText = ""
  private let expenseId: String
  private let currency: CurrencyCode
  private let deps: AppDependencies

  init(deps: AppDependencies, expenseId: String, initialAmount: Int, currency: CurrencyCode) {
    self.deps = deps
    self.expenseId = expenseId
    self.currency = currency
    amountText = MoneyFormatter.formatMinorUnitsAsInput(initialAmount, currency: currency)
  }

  var canSave: Bool { amountMinor != nil }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    _ = try await deps.api.updateExpenseAmount(id: expenseId, amount: amount)
    deps.invalidateAfter(.expenseChange)
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
    amountText = MoneyFormatter.formatMinorUnitsAsInput(item.amount, currency: item.currency)
  }

  var canSave: Bool { amountMinor != nil }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: item.currency)
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
    deps.invalidateAfter(.expenseChange)
  }
}
