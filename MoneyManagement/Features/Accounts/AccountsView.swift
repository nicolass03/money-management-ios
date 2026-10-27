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
          if !viewModel.items.isEmpty, let netWorth = viewModel.netWorth {
            TerminalBadge(
              text: deps.formatMoney(netWorth, currency: deps.displayCurrency),
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

        TransfersSection(viewModel: viewModel, deps: deps)
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
    .sheet(item: $viewModel.interestAccount) { account in
      AccountInterestSheet(deps: deps, account: account)
    }
    .sheet(item: $viewModel.transferSheet) { target in
      TransferFormSheet(deps: deps, target: target) {
        Task { await viewModel.load() }
      }
    }
    .confirmationDialog(L10n.t("Delete transfer?"), isPresented: Binding(
      get: { viewModel.deleteTransferTarget != nil },
      set: { if !$0 { viewModel.deleteTransferTarget = nil } }
    )) {
      Button(L10n.t("delete"), role: .destructive) {
        if let target = viewModel.deleteTransferTarget {
          Task { await viewModel.deleteTransfer(target) }
        }
      }
    } message: {
      if case .recurring = viewModel.deleteTransferTarget {
        Text(L10n.t("stops future transfers; past transfers are kept."))
      } else {
        Text(L10n.t("both balances go back to before it."))
      }
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
            if account.excludeFromProjections {
              Text(L10n.t("not in projections"))
                .font(AppFont.mono(size: 10))
                .foregroundStyle(palette.muted)
            }
            if let rate = account.interestRateLabel {
              Text(rate)
                .font(AppFont.mono(size: 10))
                .foregroundStyle(palette.muted)
            }
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

          if account.interestRateBps > 0 {
            Button(L10n.t("interest")) {
              viewModel.interestAccount = account
            }
            .font(AppFont.mono(size: 12))
            .foregroundStyle(palette.accent)
          }

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
      // Currency is fixed once an account is created: existing rows are stored in it and summed
      // without conversion, so changing it would corrupt the balance.
      CurrencyPicker(selection: $model.currency)
        .disabled(model.isEditing)
      if model.isEditing {
        Text(L10n.t("currency can't be changed after creation"))
          .font(AppFont.mono(size: 11))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      AmountTextField(
        text: $model.initialAmountText,
        label: L10n.t("starting balance (on projection start date)"),
        placeholder: "0.00"
      )
      AmountTextField(
        text: $model.interestRateText,
        label: L10n.t("interest rate % (optional)"),
        placeholder: "3.72"
      )
      VStack(alignment: .leading, spacing: 4) {
        Text(L10n.t("rate type"))
          .font(AppFont.mono(size: 12))
          .foregroundStyle(.secondary)
        Picker(L10n.t("rate type"), selection: $model.interestRateType) {
          ForEach(InterestRateType.allCases) { type in
            Text(type.label).tag(type)
          }
        }
        .pickerStyle(.menu)
        .font(AppFont.mono(size: 14))
      }
      Text(L10n.t("for savings accounts that pay interest every day. enter the rate your bank shows and how it quotes it. interest is added daily as income to this account, compounding on its balance. leave blank for no interest."))
        .font(AppFont.mono(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      TerminalToggle(label: L10n.t("exclude from projections"), isOn: $model.excludeFromProjections)
      Text(L10n.t("its balance, income and expenses won't count in projections. transfers between it and your other accounts count as money in or out."))
        .font(AppFont.mono(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// An account's daily interest credits, grouped by month (newest first). They stay out of the
/// income list so they don't crowd it.
private struct AccountInterestSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.appPalette) private var palette
  let deps: AppDependencies
  let account: Account
  @State private var credits: [InterestCredit] = []
  @State private var isLoading = true
  @State private var errorMessage: String?

  private struct Month: Identifiable {
    let id: String
    var total = 0
    var credits: [InterestCredit] = []
  }

  /// Credits grouped by `YYYY-MM`, keeping their newest-first order.
  private var months: [Month] {
    var groups: [Month] = []
    for credit in credits {
      let month = String(credit.date.prefix(7))
      if groups.last?.id != month {
        groups.append(Month(id: month))
      }
      groups[groups.count - 1].total += credit.amount
      groups[groups.count - 1].credits.append(credit)
    }
    return groups
  }

  var body: some View {
    NavigationStack {
      TerminalScreen {
        VStack(alignment: .leading, spacing: 16) {
          SectionHeader(
            title: L10n.t("interest"),
            subtitle: [AccountPicker.label(account), account.interestRateLabel]
              .compactMap { $0 }
              .joined(separator: " · ")
          )

          if let errorMessage {
            ErrorBanner(message: errorMessage) { Task { await load() } }
          }

          if credits.isEmpty && !isLoading && errorMessage == nil {
            EmptyStateCard(message: L10n.t("> no interest credited yet — it's added each day from the day after you turn it on."))
          } else if !credits.isEmpty {
            row(L10n.t("total earned"), credits.reduce(0) { $0 + $1.amount }, size: 14)
            ForEach(months) { month in
              TerminalCard {
                VStack(alignment: .leading, spacing: 6) {
                  row(month.id, month.total, size: 12)
                  Divider().overlay(palette.border)
                  ForEach(month.credits) { credit in
                    row(credit.date, credit.amount, size: 12, muted: true)
                  }
                }
              }
            }
          }
        }
      }
      .overlay { if isLoading { LoadingOverlay() } }
      .task { await load() }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.t("done")) { dismiss() }
        }
      }
    }
  }

  private func row(_ label: String, _ amount: Int, size: CGFloat, muted: Bool = false) -> some View {
    HStack {
      Text(label)
        .foregroundStyle(muted ? palette.muted : palette.text)
      Spacer()
      Text("+\(MoneyFormatter.format(amount, currency: account.currency))")
        .foregroundStyle(palette.accent)
    }
    .font(AppFont.mono(size: size))
  }

  private func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      credits = try await deps.api.getAccountInterest(id: account.id)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
