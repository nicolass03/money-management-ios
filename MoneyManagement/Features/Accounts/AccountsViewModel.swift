import Foundation
import Observation

/// What a transfer sheet edits (or deletes): a new transfer, a transfer, or a recurring transfer.
enum TransferTarget: Identifiable {
  case new
  case transfer(Transfer)
  case recurring(RecurringTransfer)

  var id: String {
    switch self {
    case .new: "new"
    case .transfer(let transfer): transfer.id
    case .recurring(let recurring): recurring.id
    }
  }
}

@Observable
@MainActor
final class AccountsViewModel {
  private let deps: AppDependencies

  var items: [Account] = []
  var transfers: [Transfer] = []
  var recurringTransfers: [RecurringTransfer] = []
  var isLoading = false
  var errorMessage: String?

  var editing: Account?
  var showForm = false
  var deleteTarget: Account?
  /// The account whose interest credits are shown.
  var interestAccount: Account?
  var transferSheet: TransferTarget?
  var deleteTransferTarget: TransferTarget?

  init(deps: AppDependencies) {
    self.deps = deps
  }

  /// Net worth: every account's current balance summed into the display currency, or `nil` when a
  /// foreign-currency account can't be converted (missing FX rates). Returning nil rather than a
  /// raw sum avoids a meaningless total that mixes currencies (and minor-unit divisors).
  var netWorth: Int? {
    let displayCurrency = deps.displayCurrency
    var sum = 0
    for account in items {
      if account.currency == displayCurrency {
        sum += account.balance
        continue
      }
      guard
        let rates = deps.rates,
        let fromRate = rates.rates[account.currency.rawValue.uppercased()],
        rates.rates[displayCurrency.rawValue.uppercased()] != nil,
        fromRate > 0
      else {
        return nil
      }
      sum += CurrencyConverter.convert(
        amountMinor: account.balance,
        from: account.currency,
        to: displayCurrency,
        rates: rates
      )
    }
    return sum
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
      async let accountsTask = deps.dataStore.getAccounts { [deps] in
        try await deps.api.getAccounts()
      }
      async let transfersTask = deps.dataStore.getTransfers { [deps] in
        try await deps.api.getTransfers()
      }
      async let recurringTask = deps.dataStore.getRecurringTransfers { [deps] in
        try await deps.api.getRecurringTransfers()
      }
      (items, transfers, recurringTransfers) = try await (accountsTask, transfersTask, recurringTask)
    } catch {
      guard shouldSurfaceLoadError(error, isCurrent: true) else { return }
      errorMessage = error.localizedDescription
    }
  }

  func deleteTransfer(_ target: TransferTarget) async {
    do {
      switch target {
      case .new: return
      case .transfer(let transfer): try await deps.api.deleteTransfer(id: transfer.id)
      case .recurring(let recurring): try await deps.api.deleteRecurringTransfer(id: recurring.id)
      }
      deps.invalidateAfter(.transferChange)
      Haptics.light()
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func delete(_ account: Account) async {
    do {
      try await deps.api.deleteAccount(id: account.id)
      deps.invalidateAfter(.accountChange)
      Haptics.light()
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

@Observable
@MainActor
final class AccountFormModel {
  var name = ""
  var currency: CurrencyCode = .eur
  var initialAmountText = ""
  var excludeFromProjections = false
  /// Percent text, e.g. "8.25"; blank = no interest.
  var interestRateText = ""
  var interestRateType: InterestRateType = .apy

  private let editing: Account?
  private let deps: AppDependencies

  var isEditing: Bool { editing != nil }

  init(deps: AppDependencies, editing: Account? = nil) {
    self.deps = deps
    self.editing = editing
    if let editing {
      name = editing.name ?? ""
      currency = editing.currency
      initialAmountText = MoneyFormatter.formatMinorUnitsAsInput(editing.initialAmount, currency: editing.currency)
      excludeFromProjections = editing.excludeFromProjections
      if editing.interestRateBps > 0 {
        interestRateText = String(format: "%.2f", Double(editing.interestRateBps) / 100)
      }
      interestRateType = editing.interestRateType
    } else {
      currency = deps.displayCurrency
    }
  }

  var canSave: Bool { amountMinor != nil && interestRateBps != nil }

  /// A starting balance is allowed to be zero, so an empty field reads as 0.
  var amountMinor: Int? {
    let trimmed = initialAmountText.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return 0 }
    return MoneyFormatter.parseToMinorUnits(trimmed, currency: currency)
  }

  /// Percent text (up to 2 decimals) → basis points. Blank means no interest (0); nil when invalid
  /// or above 100%.
  var interestRateBps: Int? {
    let trimmed = interestRateText.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return 0 }
    guard trimmed.range(of: #"^\d{1,3}(\.\d{1,2})?$"#, options: .regularExpression) != nil,
          let percent = Double(trimmed) else { return nil }
    let bps = Int((percent * 100).rounded())
    return bps <= 10_000 ? bps : nil
  }

  func save() async throws {
    guard let amount = amountMinor, let interestRateBps else { return }
    let trimmedName = name.trimmingCharacters(in: .whitespaces)
    let body = CreateAccountRequest(
      name: trimmedName.isEmpty ? nil : trimmedName,
      currency: currency,
      initialAmount: amount,
      excludeFromProjections: excludeFromProjections,
      interestRateBps: interestRateBps,
      interestRateType: interestRateType
    )
    if let editing {
      _ = try await deps.api.updateAccount(id: editing.id, body)
    } else {
      _ = try await deps.api.createAccount(body)
    }
    deps.invalidateAfter(.accountChange)
  }
}

@Observable
@MainActor
final class TransferFormModel {
  var name = ""
  var fromAccountId: String?
  var toAccountId: String?
  var amountText = ""
  /// The transfer date, or the first occurrence of a recurring transfer.
  var date = PayPeriodLogic.todayISO()
  var repeats = false
  var frequency: PayFrequency = .monthly
  var accounts: [Account] = []

  private let target: TransferTarget
  private let deps: AppDependencies

  init(deps: AppDependencies, target: TransferTarget) {
    self.deps = deps
    self.target = target
    switch target {
    case .new:
      break
    case .transfer(let transfer):
      name = transfer.name ?? ""
      fromAccountId = transfer.fromAccountId
      toAccountId = transfer.toAccountId
      amountText = MoneyFormatter.formatMinorUnitsAsInput(transfer.amount, currency: transfer.currency)
      date = transfer.date
    case .recurring(let recurring):
      name = recurring.name ?? ""
      fromAccountId = recurring.fromAccountId
      toAccountId = recurring.toAccountId
      amountText = MoneyFormatter.formatMinorUnitsAsInput(recurring.amount, currency: recurring.currency)
      date = recurring.anchorDate
      frequency = recurring.frequency
      repeats = true
    }
  }

  var isEditing: Bool {
    if case .new = target { return false }
    return true
  }

  var isRecurring: Bool {
    if case .transfer = target { return false }
    return repeats
  }

  /// An occurrence's date and accounts follow its schedule (the API rejects changing them).
  var isLocked: Bool {
    if case .transfer(let transfer) = target { return transfer.recurringTransferId != nil }
    return false
  }

  private var existing: (toAccountId: String, currency: CurrencyCode)? {
    switch target {
    case .new: nil
    case .transfer(let transfer): (transfer.toAccountId, transfer.currency)
    case .recurring(let recurring): (recurring.toAccountId, recurring.currency)
    }
  }

  /// The source sets the currency. When editing a row whose source was archived (absent from
  /// `accounts`) this is nil and the row's own currency is kept, never the first account's.
  private var fromAccount: Account? {
    if let match = accounts.first(where: { $0.id == fromAccountId }) { return match }
    return isEditing ? nil : accounts.first
  }

  var currency: CurrencyCode {
    fromAccount?.currency ?? existing?.currency ?? deps.displayCurrency
  }

  /// v1 transfers are same-currency: the destination is another account in the source's currency.
  var toOptions: [Account] {
    accounts.filter { $0.currency == currency && $0.id != fromAccountId }
  }

  func loadAccounts() async {
    accounts = (try? await deps.dataStore.getAccounts { [deps] in try await deps.api.getAccounts() }) ?? []
    if fromAccountId == nil { fromAccountId = accounts.first?.id }
    normalizeDestination()
  }

  /// Keeps the destination valid after the source changes: an account from `toOptions`, or the
  /// row's own (possibly archived) destination while editing.
  func normalizeDestination() {
    let keepsExisting = toAccountId != nil
      && toAccountId == existing?.toAccountId
      && existing?.currency == currency
      && toAccountId != fromAccountId
    if keepsExisting || toOptions.contains(where: { $0.id == toAccountId }) { return }
    toAccountId = toOptions.first?.id
  }

  var amountMinor: Int? {
    MoneyFormatter.parseToMinorUnits(amountText, currency: currency).flatMap { $0 > 0 ? $0 : nil }
  }

  var canSave: Bool {
    amountMinor != nil && fromAccountId != nil && toAccountId != nil && fromAccountId != toAccountId
  }

  var upcomingDates: [String] {
    guard isRecurring, date.count == 10 else { return [] }
    let schedule = PayPeriodLogic.ScheduleInput(anchorDate: date, frequency: frequency, lastPaymentDate: nil)
    return PayPeriodLogic.getUpcomingOccurrences(schedule: schedule, count: 3)
  }

  func save() async throws {
    guard let amount = amountMinor, let fromAccountId, let toAccountId else { return }
    let trimmedName = name.trimmingCharacters(in: .whitespaces)
    let name = trimmedName.isEmpty ? nil : trimmedName
    if isRecurring {
      let body = RecurringTransferRequest(
        name: name,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        currency: currency,
        anchorDate: date,
        frequency: frequency
      )
      if case .recurring(let recurring) = target {
        _ = try await deps.api.updateRecurringTransfer(id: recurring.id, body)
      } else {
        _ = try await deps.api.createRecurringTransfer(body)
      }
    } else {
      let body = TransferRequest(
        name: name,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        currency: currency,
        date: date
      )
      if case .transfer(let transfer) = target {
        _ = try await deps.api.updateTransfer(id: transfer.id, body)
      } else {
        _ = try await deps.api.createTransfer(body)
      }
    }
    deps.invalidateAfter(.transferChange)
  }
}
