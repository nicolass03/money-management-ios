import SwiftUI

struct BudgetsView: View {
  @Environment(\.appPalette) private var palette
  @Bindable var viewModel: BudgetsViewModel
  let deps: AppDependencies

  var body: some View {
    TerminalScreen {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          SectionHeader(title: L10n.t("budgets"), subtitle: L10n.t("allocated spending pools"))
          Spacer()
          if viewModel.isLoading || deps.isLoadingContext {
            Skeleton()
              .frame(width: 96, height: 20)
          } else if !viewModel.budgets.isEmpty {
            TerminalBadge(text: deps.formatMoney(viewModel.totalAllocated, currency: deps.displayCurrency), style: .accent)
          }
        }

        if let error = viewModel.errorMessage {
          ErrorBanner(message: error) { Task { await viewModel.load() } }
        }

        if !viewModel.isLoading && !deps.isLoadingContext {
          TerminalButton(title: L10n.t("+ add budget")) {
            viewModel.editingBudget = nil
            viewModel.showBudgetForm = true
          }
        }

        if viewModel.isLoading || deps.isLoadingContext {
          CardListSkeleton(count: 3, label: L10n.t("loading budgets"))
        } else if viewModel.budgets.isEmpty {
          EmptyStateCard(message: L10n.t("> no budgets yet."))
        } else {
          ForEach(viewModel.groupedBudgets, id: \.0) { status, items in
            VStack(alignment: .leading, spacing: 10) {
              Text(String(format: L10n.t("> %@"), status.label))
                .font(AppFont.mono(size: 12, weight: .medium))
                .foregroundStyle(palette.muted)

              ForEach(items) { budget in
                budgetCard(budget)
              }
            }
          }
        }
      }
    }
    .refreshable { await viewModel.load(force: true) }
    .task { await viewModel.load() }
    .sheet(isPresented: $viewModel.showBudgetForm) {
      BudgetFormSheet(deps: deps, editing: viewModel.editingBudget) {
        viewModel.showBudgetForm = false
        Task { await viewModel.load() }
      }
      .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $viewModel.showExpenseForm) {
      if let budgetId = viewModel.expenseBudgetId,
         let budget = viewModel.budgets.first(where: { $0.id == budgetId }) {
        BudgetExpenseFormSheet(deps: deps, budget: budget) {
          viewModel.showExpenseForm = false
          Task {
            await viewModel.loadExpenses(for: budgetId)
            await viewModel.load()
          }
        }
        .presentationDetents([.medium])
      }
    }
    .confirmationDialog(L10n.t("Delete budget?"), isPresented: Binding(
      get: { viewModel.deleteBudgetTarget != nil },
      set: { if !$0 { viewModel.deleteBudgetTarget = nil } }
    )) {
      Button(L10n.t("delete"), role: .destructive) {
        if let target = viewModel.deleteBudgetTarget {
          Task { await viewModel.deleteBudget(target) }
        }
      }
    }
    .confirmationDialog(L10n.t("Delete expense?"), isPresented: Binding(
      get: { viewModel.deleteExpenseTarget != nil },
      set: { if !$0 { viewModel.deleteExpenseTarget = nil } }
    )) {
      Button(L10n.t("delete"), role: .destructive) {
        if let target = viewModel.deleteExpenseTarget {
          Task { await viewModel.deleteBudgetExpense(budgetId: target.budgetId, expense: target.expense) }
        }
      }
    }
  }

  private func budgetCard(_ budget: BudgetWithTags) -> some View {
    let isExpanded = viewModel.expandedBudgetIds.contains(budget.id)

    return TerminalCard {
      VStack(alignment: .leading, spacing: 12) {
        Button {
          Task { await viewModel.toggleExpanded(budget) }
        } label: {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text(budget.name)
                .font(AppFont.mono(size: 14, weight: .medium))
                .foregroundStyle(palette.text)
              Spacer()
              Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12))
                .foregroundStyle(palette.muted)
            }

            if let start = budget.startDate, let end = budget.endDate {
              Text(String(format: L10n.t("> %@ → %@"), start, end))
                .font(AppFont.mono(size: 11))
                .foregroundStyle(palette.muted)
            } else {
              Text(L10n.t("> open-ended"))
                .font(AppFont.mono(size: 11))
                .foregroundStyle(palette.muted)
            }

            HStack {
              MoneyLabel(amount: budget.spent, currency: budget.currency, displayCurrency: deps.displayCurrency, rates: deps.rates, size: 12)
              Text(L10n.t("/"))
                .font(AppFont.mono(size: 12))
                .foregroundStyle(palette.muted)
              MoneyLabel(amount: budget.amount, currency: budget.currency, displayCurrency: deps.displayCurrency, rates: deps.rates, size: 12)
            }

            TerminalProgressBar(spent: budget.spent, total: budget.amount)
          }
        }
        .buttonStyle(.plain)

        if isExpanded {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              Button(L10n.t("edit")) {
                viewModel.editingBudget = budget
                viewModel.showBudgetForm = true
              }
              .font(AppFont.mono(size: 12))
              .foregroundStyle(palette.accent)

              Button(L10n.t("delete")) {
                viewModel.deleteBudgetTarget = budget
              }
              .font(AppFont.mono(size: 12))
              .foregroundStyle(palette.danger)

              Spacer()

              if budget.spent < budget.amount {
                Button(L10n.t("+ expense")) {
                  viewModel.expenseBudgetId = budget.id
                  viewModel.showExpenseForm = true
                }
                .font(AppFont.mono(size: 12, weight: .medium))
                .foregroundStyle(palette.accent)
              }
            }

            if viewModel.loadingExpenses.contains(budget.id) {
              CardListSkeleton(count: 1, label: L10n.t("loading budget expenses"))
            } else if let expenses = viewModel.budgetExpenses[budget.id], !expenses.isEmpty {
              ForEach(expenses) { expense in
                HStack {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(expense.name)
                      .font(AppFont.mono(size: 12))
                      .foregroundStyle(palette.text)
                    Text(String(format: L10n.t("> %@"), expense.date))
                      .font(AppFont.mono(size: 10))
                      .foregroundStyle(palette.muted)
                  }
                  Spacer()
                  MoneyLabel(amount: expense.amount, currency: expense.currency, displayCurrency: deps.displayCurrency, rates: deps.rates, size: 12)
                  Button {
                    viewModel.deleteExpenseTarget = (budget.id, expense)
                  } label: {
                    Image(systemName: "trash")
                      .font(.system(size: 12))
                      .foregroundStyle(palette.danger)
                  }
                  .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
              }
            } else {
              Text(L10n.t("> no expenses in this budget."))
                .font(AppFont.mono(size: 11))
                .foregroundStyle(palette.muted)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct BudgetFormSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: BudgetFormModel
  @State private var isSaving = false
  @State private var errorMessage: String?
  let onSaved: () -> Void

  init(deps: AppDependencies, editing: BudgetWithTags?, onSaved: @escaping () -> Void) {
    _model = State(initialValue: BudgetFormModel(deps: deps, editing: editing))
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(
      title: model.isEditing ? L10n.t("edit budget") : L10n.t("add budget"),
      isSaving: isSaving,
      canSave: model.canSave,
      onSave: { Task { await save() } }
    ) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      TerminalTextField(label: L10n.t("name"), placeholder: L10n.t("vacation"), text: $model.name)
      AmountTextField(text: $model.amountText, placeholder: "1500.00")
      CurrencyPicker(selection: $model.currency)
      TerminalTextField(label: L10n.t("start date (optional)"), placeholder: L10n.t("YYYY-MM-DD"), text: $model.startDate, keyboardType: .numbersAndPunctuation)
      TerminalTextField(label: L10n.t("end date (optional)"), placeholder: L10n.t("YYYY-MM-DD"), text: $model.endDate, keyboardType: .numbersAndPunctuation)
      TagsInputField(tagsText: $model.tagsText)
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

private struct BudgetExpenseFormSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.appPalette) private var palette
  @State private var model: BudgetExpenseFormModel
  @State private var isSaving = false
  @State private var errorMessage: String?
  let onSaved: () -> Void

  init(deps: AppDependencies, budget: BudgetWithTags, onSaved: @escaping () -> Void) {
    _model = State(initialValue: BudgetExpenseFormModel(deps: deps, budget: budget))
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(
      title: L10n.t("add budget expense"),
      isSaving: isSaving,
      canSave: model.canSave,
      onSave: { Task { await save() } }
    ) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      if model.remaining <= 0 {
        Text(L10n.t("> budget fully spent."))
          .font(AppFont.mono(size: 11))
          .foregroundStyle(palette.muted)
      } else {
        if model.isDated {
          TerminalTextField(label: L10n.t("name (optional)"), placeholder: L10n.t("item"), text: $model.name)
        }
        AmountTextField(text: $model.amountText, placeholder: "50.00")
        TerminalTextField(label: L10n.t("date"), placeholder: L10n.t("YYYY-MM-DD"), text: $model.date, keyboardType: .numbersAndPunctuation)
      }
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
