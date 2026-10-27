import SwiftUI

/// Transfers between the user's accounts, on the accounts tab: recurring transfers first, then
/// every transfer (newest first). Sheets and the delete dialog are owned by `AccountsView`.
struct TransfersSection: View {
  @Environment(\.appPalette) private var palette
  let viewModel: AccountsViewModel
  let deps: AppDependencies

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: L10n.t("transfers"), subtitle: L10n.t("move money between your accounts"))

      TerminalButton(title: L10n.t("+ new transfer")) {
        viewModel.transferSheet = .new
      }
      .disabled(viewModel.items.count < 2)

      if viewModel.recurringTransfers.isEmpty && viewModel.transfers.isEmpty {
        EmptyStateCard(message: L10n.t("> no transfers yet."))
      }

      ForEach(viewModel.recurringTransfers) { recurring in
        card(
          title: recurring.name,
          meta: "\(route(recurring.fromAccountId, recurring.toAccountId)) · \(recurring.frequency.label) · \(status(recurring))",
          isRecurring: true,
          amount: recurring.amount,
          currency: recurring.currency,
          target: .recurring(recurring)
        )
      }

      ForEach(viewModel.transfers) { transfer in
        card(
          title: transfer.name,
          meta: "\(transfer.date) · \(route(transfer.fromAccountId, transfer.toAccountId))",
          isRecurring: transfer.recurringTransferId != nil,
          amount: transfer.amount,
          currency: transfer.currency,
          target: .transfer(transfer)
        )
      }
    }
  }

  /// `viewModel.items` holds active accounts only; a missing id belongs to an archived account.
  private func accountName(_ id: String) -> String {
    guard let account = viewModel.items.first(where: { $0.id == id }) else {
      return L10n.t("archived account")
    }
    let trimmed = account.name?.trimmingCharacters(in: .whitespaces)
    return (trimmed?.isEmpty == false ? trimmed : nil) ?? L10n.t("unnamed")
  }

  private func route(_ fromId: String, _ toId: String) -> String {
    "\(accountName(fromId)) → \(accountName(toId))"
  }

  /// The daily job skips a recurring transfer whose account was archived.
  private func status(_ recurring: RecurringTransfer) -> String {
    let active = Set(viewModel.items.map(\.id))
    guard active.contains(recurring.fromAccountId), active.contains(recurring.toAccountId) else {
      return L10n.t("paused — account archived")
    }
    let next = PayPeriodLogic.getUpcomingOccurrences(
      schedule: PayPeriodLogic.scheduleInput(from: recurring),
      count: 1
    ).first ?? recurring.anchorDate
    return String(format: L10n.t("next %@"), next)
  }

  private func card(
    title: String?,
    meta: String,
    isRecurring: Bool,
    amount: Int,
    currency: CurrencyCode,
    target: TransferTarget
  ) -> some View {
    let trimmed = title?.trimmingCharacters(in: .whitespaces)
    let title = (trimmed?.isEmpty == false ? trimmed : nil) ?? L10n.t("transfer")
    return TerminalCard {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
              Text(title)
                .font(AppFont.mono(size: 14, weight: .medium))
                .foregroundStyle(palette.text)
              if isRecurring {
                TerminalBadge(text: L10n.t("recurring"), style: .muted)
              }
            }
            Text(meta)
              .font(AppFont.mono(size: 11))
              .foregroundStyle(palette.muted)
          }
          Spacer()
          MoneyLabel(amount: amount, currency: currency, displayCurrency: currency, rates: deps.rates)
        }

        HStack(spacing: 8) {
          Button(L10n.t("edit")) { viewModel.transferSheet = target }
            .font(AppFont.mono(size: 12))
            .foregroundStyle(palette.accent)

          Button(L10n.t("delete")) { viewModel.deleteTransferTarget = target }
            .font(AppFont.mono(size: 12))
            .foregroundStyle(palette.danger)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct TransferFormSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.appPalette) private var palette
  @State private var model: TransferFormModel
  @State private var isSaving = false
  @State private var errorMessage: String?
  let deps: AppDependencies
  let onSaved: () -> Void

  init(deps: AppDependencies, target: TransferTarget, onSaved: @escaping () -> Void) {
    _model = State(initialValue: TransferFormModel(deps: deps, target: target))
    self.deps = deps
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(
      title: model.isEditing ? L10n.t("edit transfer") : L10n.t("new transfer"),
      isSaving: isSaving,
      canSave: model.canSave,
      onSave: { Task { await save() } }
    ) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      TerminalTextField(label: L10n.t("name (optional)"), placeholder: L10n.t("savings, rent pot…"), text: $model.name)
      AccountPicker(accounts: model.accounts, selection: $model.fromAccountId, label: L10n.t("from"))
        .disabled(model.isLocked)
      AccountPicker(accounts: model.toOptions, selection: $model.toAccountId, label: L10n.t("to"))
        .disabled(model.isLocked)
      if model.toAccountId == nil {
        hint(L10n.t("no other account in this currency"), color: palette.warning)
      }
      AmountTextField(text: $model.amountText, label: "\(L10n.t("amount")) (\(model.currency.label))")
      if !model.isEditing {
        Toggle(L10n.t("repeat"), isOn: $model.repeats)
          .font(AppFont.mono(size: 14))
          .tint(palette.accent)
      }
      TerminalTextField(
        label: model.isRecurring ? L10n.t("first transfer") : L10n.t("date"),
        placeholder: L10n.t("YYYY-MM-DD"),
        text: $model.date,
        keyboardType: .numbersAndPunctuation
      )
      .disabled(model.isLocked)
      if model.isLocked {
        hint(L10n.t("date and accounts follow its recurring schedule"), color: palette.muted)
      }
      if model.isRecurring {
        FrequencyPicker(selection: $model.frequency)
        if !model.upcomingDates.isEmpty {
          hint("\(L10n.t("next transfers")): \(model.upcomingDates.joined(separator: ", "))", color: palette.muted)
        }
      }
    }
    .task { await model.loadAccounts() }
    .onChange(of: model.fromAccountId) { model.normalizeDestination() }
  }

  private func hint(_ text: String, color: Color) -> some View {
    Text(text)
      .font(AppFont.mono(size: 11))
      .foregroundStyle(color)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func save() async {
    isSaving = true
    errorMessage = nil
    defer { isSaving = false }
    do {
      try await model.save()
      Haptics.success()
      dismiss()
      onSaved()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
