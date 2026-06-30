import SwiftUI

struct AccountsView: View {
  @Environment(\.appPalette) private var palette
  @State private var viewModel: AccountsViewModel
  let deps: AppDependencies

  init(viewModel: AccountsViewModel, deps: AppDependencies) {
    _viewModel = State(initialValue: viewModel)
    self.deps = deps
  }

  var body: some View {
    TerminalScreen {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          SectionHeader(title: L10n.t("accounts"), subtitle: L10n.t("cash and bank balances"))
          Spacer()
          if !viewModel.items.isEmpty {
            TerminalBadge(
              text: deps.formatMoney(viewModel.netWorth, currency: deps.displayCurrency),
              style: .accent
            )
          }
        }

        if let error = viewModel.errorMessage {
          ErrorBanner(message: error) { Task { await viewModel.load() } }
        }

        TerminalButton(title: L10n.t("+ add account")) {
          viewModel.editing = nil
          viewModel.showForm = true
        }

        if viewModel.items.isEmpty && !viewModel.isLoading {
          EmptyStateCard(message: L10n.t("> no accounts yet."))
        } else {
          ForEach(viewModel.items) { account in
            accountCard(account)
          }
        }
      }
    }
    .overlay { if viewModel.isLoading { LoadingOverlay() } }
    .refreshable { await viewModel.load(force: true) }
    .task { await viewModel.load() }
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $viewModel.showForm) {
      AccountFormSheet(deps: deps, editing: viewModel.editing) {
        viewModel.showForm = false
        Task { await viewModel.load() }
      }
      .presentationDetents([.medium])
    }
    .confirmationDialog(L10n.t("Archive account?"), isPresented: Binding(
      get: { viewModel.deleteTarget != nil },
      set: { if !$0 { viewModel.deleteTarget = nil } }
    )) {
      Button(L10n.t("archive"), role: .destructive) {
        if let target = viewModel.deleteTarget {
          Task { await viewModel.delete(target) }
        }
      }
    } message: {
      Text(L10n.t("archiving keeps history but removes the account from pickers and totals."))
    }
  }

  private func accountCard(_ account: Account) -> some View {
    let name = (account.name?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 }
      ?? L10n.t("unnamed")
    return TerminalCard {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(name)
              .font(AppFont.mono(size: 14, weight: .medium))
              .foregroundStyle(palette.text)
            Text(String(format: L10n.t("> initial: %@"),
                        MoneyFormatter.format(account.initialAmount, currency: account.currency,
                                              displayCurrency: account.currency, rates: deps.rates)))
              .font(AppFont.mono(size: 11))
              .foregroundStyle(palette.muted)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            Text(L10n.t("balance"))
              .font(AppFont.mono(size: 10))
              .foregroundStyle(palette.muted)
            // Native balance in the account's own currency.
            MoneyLabel(amount: account.balance, currency: account.currency,
                       displayCurrency: account.currency, rates: deps.rates)
          }
        }

        HStack(spacing: 8) {
          Button(L10n.t("edit")) {
            viewModel.editing = account
            viewModel.showForm = true
          }
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.accent)

          Button(L10n.t("archive")) {
            viewModel.deleteTarget = account
          }
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.danger)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct AccountFormSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: AccountFormModel
  @State private var isSaving = false
  @State private var errorMessage: String?
  let onSaved: () -> Void

  init(deps: AppDependencies, editing: Account?, onSaved: @escaping () -> Void) {
    _model = State(initialValue: AccountFormModel(deps: deps, editing: editing))
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(
      title: model.isEditing ? L10n.t("edit account") : L10n.t("add account"),
      isSaving: isSaving,
      canSave: model.canSave,
      onSave: { Task { await save() } }
    ) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      TerminalTextField(label: L10n.t("name (optional)"), placeholder: L10n.t("cash, euros…"), text: $model.name)
      CurrencyPicker(selection: $model.currency)
      AmountTextField(text: $model.initialAmountText, placeholder: "0.00")
    }
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
