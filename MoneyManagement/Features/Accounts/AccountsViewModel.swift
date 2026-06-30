import Foundation
import Observation

@Observable
@MainActor
final class AccountsViewModel {
  private let deps: AppDependencies

  var items: [Account] = []
  var isLoading = false
  var errorMessage: String?

  var editing: Account?
  var showForm = false
  var deleteTarget: Account?

  init(deps: AppDependencies) {
    self.deps = deps
  }

  /// Net worth: every account's current balance summed into the display currency.
  var netWorth: Int {
    items.reduce(0) { partial, account in
      partial + CurrencyConverter.convert(
        amountMinor: account.balance,
        from: account.currency,
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
      items = try await deps.dataStore.getAccounts { [deps] in
        try await deps.api.getAccounts()
      }
    } catch {
      guard shouldSurfaceLoadError(error, isCurrent: true) else { return }
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
    } else {
      currency = deps.displayCurrency
    }
  }

  var canSave: Bool { amountMinor != nil }

  /// A starting balance is allowed to be zero, so an empty field reads as 0.
  var amountMinor: Int? {
    let trimmed = initialAmountText.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return 0 }
    return MoneyFormatter.parseToMinorUnits(trimmed, currency: currency)
  }

  func save() async throws {
    guard let amount = amountMinor else { return }
    let trimmedName = name.trimmingCharacters(in: .whitespaces)
    let body = CreateAccountRequest(
      name: trimmedName.isEmpty ? nil : trimmedName,
      currency: currency,
      initialAmount: amount
    )
    if let editing {
      _ = try await deps.api.updateAccount(id: editing.id, body)
    } else {
      _ = try await deps.api.createAccount(body)
    }
    deps.invalidateAfter(.accountChange)
  }
}
