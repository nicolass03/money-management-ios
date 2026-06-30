import SwiftUI

struct PlannedExpensesView: View {
  @Environment(\.appPalette) private var palette
  @State private var viewModel: PlannedExpensesViewModel
  let deps: AppDependencies

  init(deps: AppDependencies) {
    self.deps = deps
    _viewModel = State(initialValue: PlannedExpensesViewModel(deps: deps))
  }

  var body: some View {
    TerminalScreen {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          SectionHeader(title: L10n.t("one-time"), subtitle: L10n.t("planned future expenses"))
          Spacer()
          TerminalBadge(text: deps.formatMoney(viewModel.upcomingTotal, currency: deps.displayCurrency), style: .accent)
        }

        if let error = viewModel.errorMessage {
          ErrorBanner(message: error) { Task { await viewModel.load() } }
        }

        TerminalButton(title: L10n.t("+ add one-time")) {
          viewModel.editing = nil
          viewModel.showForm = true
        }

        if viewModel.items.isEmpty && !viewModel.isLoading {
          EmptyStateCard(message: L10n.t("> no planned expenses yet."))
        } else {
          ForEach(viewModel.items) { item in
            plannedCard(item)
          }
        }
      }
    }
    .overlay { if viewModel.isLoading { LoadingOverlay() } }
    .refreshable { await viewModel.load(force: true) }
    .task { await viewModel.load() }
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $viewModel.showForm) {
      PlannedExpenseFormSheet(deps: deps, editing: viewModel.editing, knownTags: viewModel.tags) {
        viewModel.showForm = false
        Task { await viewModel.load() }
      }
      .presentationDetents([.medium, .large])
    }
    .confirmationDialog(L10n.t("Delete planned expense?"), isPresented: Binding(
      get: { viewModel.deleteTarget != nil },
      set: { if !$0 { viewModel.deleteTarget = nil } }
    )) {
      Button(L10n.t("delete"), role: .destructive) {
        if let target = viewModel.deleteTarget {
          Task { await viewModel.delete(target) }
        }
      }
    }
  }

  private func plannedCard(_ item: PlannedExpenseWithTags) -> some View {
    TerminalCard {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
              .font(AppFont.mono(size: 14, weight: .medium))
              .foregroundStyle(palette.text)
            Text(String(format: L10n.t("> %@"), item.date))
              .font(AppFont.mono(size: 11))
              .foregroundStyle(palette.muted)
          }
          Spacer()
          MoneyLabel(amount: item.amount, currency: item.currency, displayCurrency: deps.displayCurrency, rates: deps.rates)
        }

        TerminalTagFlow(tags: item.tags)

        HStack(spacing: 8) {
          Button(L10n.t("edit")) {
            viewModel.editing = item
            viewModel.showForm = true
          }
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.accent)

          Button(L10n.t("delete")) {
            viewModel.deleteTarget = item
          }
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.danger)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct PlannedExpenseFormSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: PlannedExpenseFormModel
  @State private var isSaving = false
  @State private var errorMessage: String?
  let knownTags: [String]
  let onSaved: () -> Void

  init(deps: AppDependencies, editing: PlannedExpenseWithTags?, knownTags: [String], onSaved: @escaping () -> Void) {
    _model = State(initialValue: PlannedExpenseFormModel(deps: deps, editing: editing))
    self.knownTags = knownTags
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(
      title: model.isEditing ? L10n.t("edit one-time") : L10n.t("add one-time"),
      isSaving: isSaving,
      canSave: model.canSave,
      onSave: { Task { await save() } }
    ) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      TerminalTextField(label: L10n.t("name"), placeholder: L10n.t("car repair"), text: $model.name)
      TerminalTextField(label: L10n.t("date"), placeholder: L10n.t("YYYY-MM-DD"), text: $model.date, keyboardType: .numbersAndPunctuation)
      AmountTextField(text: $model.amountText, placeholder: "500.00")
      AccountPicker(accounts: model.accounts, selection: $model.accountId)
      TagsInputField(tagsText: $model.tagsText, knownTags: knownTags)
    }
    .task { await model.loadAccounts() }
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
