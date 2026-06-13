import SwiftUI

struct ExpensesView: View {
  @Environment(\.appPalette) private var palette
  @Bindable var viewModel: ExpensesViewModel
  let deps: AppDependencies
  var onOpenSettings: () -> Void

  var body: some View {
    TerminalScreen {
      VStack(alignment: .leading, spacing: 20) {
        SectionHeader(title: "expenses", subtitle: viewModel.periodSubtitle ?? "analytics and spend by period")

        if let error = viewModel.errorMessage {
          ErrorBanner(message: error) { Task { await viewModel.load() } }
        }

        TerminalSegmentedControl(selection: $viewModel.periodKey, options: ExpensePeriodKey.allCases)
          .onChange(of: viewModel.periodKey) { _, _ in }

        if viewModel.needsPrimarySchedule {
          EmptyStateCard(
            message: "> set a primary pay schedule.",
            footnote: "> required for pay-period view."
          )
          TerminalButton(title: "open settings", action: onOpenSettings)
        } else {
          heroCard
          quickActions
          expenseList
        }
      }
    }
    .overlay { if viewModel.isLoading { LoadingOverlay() } }
    .refreshable { await viewModel.load(force: true) }
    .task { await viewModel.load() }
    .navigationDestination(for: ExpensesRoute.self) { route in
      switch route {
      case .recurring:
        RecurringExpensesView(viewModel: RecurringExpensesViewModel(deps: deps), deps: deps)
      case .planned:
        PlannedExpensesView(viewModel: PlannedExpensesViewModel(deps: deps), deps: deps)
      case .earlyPay:
        EarlyPayView(deps: deps)
      }
    }
    .sheet(isPresented: $viewModel.showExpenseForm) {
      ExpenseFormSheet(deps: deps, knownTags: viewModel.tags) {
        viewModel.showExpenseForm = false
        Task { await viewModel.load() }
      }
      .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $viewModel.showEditAmountForm) {
      if let expense = viewModel.editAmountExpense {
        ExpenseAmountFormSheet(deps: deps, expense: expense) {
          viewModel.showEditAmountForm = false
          Task { await viewModel.load() }
        }
        .presentationDetents([.medium])
      }
    }
    .confirmationDialog("Delete expense?", isPresented: Binding(
      get: { viewModel.deleteExpenseTarget != nil },
      set: { if !$0 { viewModel.deleteExpenseTarget = nil } }
    )) {
      Button("delete", role: .destructive) {
        if let target = viewModel.deleteExpenseTarget {
          Task { await viewModel.deleteExpense(target) }
        }
      }
    }
  }

  private var heroCard: some View {
    TerminalCard {
      VStack(alignment: .leading, spacing: 8) {
        Text("> total spent")
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.muted)

        MoneyLabel(
          amount: viewModel.totalSpend,
          currency: deps.displayCurrency,
          size: 36,
          weight: .medium
        )
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var quickActions: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
      NavigationLink(value: ExpensesRoute.recurring) {
        quickActionLabel(title: "recurring", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.plain)

      NavigationLink(value: ExpensesRoute.planned) {
        quickActionLabel(title: "one-time", systemImage: "calendar")
      }
      .buttonStyle(.plain)

      Button {
        viewModel.showExpenseForm = true
      } label: {
        quickActionLabel(title: "add", systemImage: "plus")
      }
      .buttonStyle(.plain)

      NavigationLink(value: ExpensesRoute.earlyPay) {
        quickActionLabel(title: "early pay", systemImage: "bolt")
      }
      .buttonStyle(.plain)
    }
  }

  private func quickActionLabel(title: String, systemImage: String) -> some View {
    VStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.system(size: 16))
      Text(title)
        .font(AppFont.mono(size: 10))
        .lineLimit(1)
    }
    .foregroundStyle(palette.text)
    .frame(maxWidth: .infinity)
    .frame(minHeight: 52)
    .background(palette.surface)
    .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
  }

  private var expenseList: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader(title: "spendings")

      if viewModel.periodItems.isEmpty {
        EmptyStateCard(message: "> no expenses in this period.")
      } else {
        ForEach(viewModel.periodItems) { item in
          expenseItemRow(item)
        }
      }
    }
  }

  private func expenseItemRow(_ item: ProjectionExpenseItem) -> some View {
    let expense = viewModel.expenseForItem(item)
    let canMutate = expense.map { !$0.isSystemGenerated } ?? false

    return VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        Text(item.name)
          .font(AppFont.mono(size: 14))
          .foregroundStyle(palette.text)
          .lineLimit(1)

        Text(" · ")
          .font(AppFont.mono(size: 14))
          .foregroundStyle(palette.muted)

        Text(item.date)
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.muted)
          .lineLimit(1)

        Spacer(minLength: 8)

        MoneyLabel(
          amount: item.convertedAmount,
          currency: deps.displayCurrency,
          size: 13,
          weight: .medium
        )
      }

      if item.isSubscription || !item.tags.isEmpty {
        HStack(spacing: 6) {
          if item.isSubscription {
            TerminalBadge(text: "subscription", style: .muted)
          }
          ForEach(item.tags, id: \.self) { tag in
            TerminalTagChip(tag: tag)
          }
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(palette.surface)
    .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
    .contextMenu {
      if canMutate, let expense {
        Button("edit amount") {
          viewModel.editAmountExpense = expense
          viewModel.showEditAmountForm = true
        }
        Button("delete", role: .destructive) {
          viewModel.deleteExpenseTarget = expense
        }
      }
    }
  }

}

enum ExpensesRoute: Hashable {
  case recurring
  case planned
  case earlyPay
}

private struct ExpenseFormSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: ExpenseFormModel
  @State private var isSaving = false
  @State private var errorMessage: String?
  let knownTags: [String]
  let onSaved: () -> Void

  init(deps: AppDependencies, knownTags: [String], onSaved: @escaping () -> Void) {
    _model = State(initialValue: ExpenseFormModel(deps: deps))
    self.knownTags = knownTags
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(title: "add expense", isSaving: isSaving, canSave: model.canSave, onSave: { Task { await save() } }) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      TerminalTextField(label: "name", placeholder: "groceries", text: $model.name)
      TerminalTextField(label: "amount (minor units)", placeholder: "2500", text: $model.amountText, keyboardType: .numberPad)
      CurrencyPicker(selection: $model.currency)
      TerminalTextField(label: "date", placeholder: "YYYY-MM-DD", text: $model.date, keyboardType: .numbersAndPunctuation)
      TagsInputField(tagsText: $model.tagsText, knownTags: knownTags)
      SubscriptionToggle(isSubscription: $model.isSubscription)
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

private struct ExpenseAmountFormSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: ExpenseAmountFormModel
  @State private var isSaving = false
  @State private var errorMessage: String?
  let onSaved: () -> Void

  init(deps: AppDependencies, expense: ExpenseWithTags, onSaved: @escaping () -> Void) {
    _model = State(initialValue: ExpenseAmountFormModel(deps: deps, expense: expense))
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(title: "edit amount", isSaving: isSaving, canSave: model.canSave, onSave: { Task { await save() } }) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      TerminalTextField(label: "amount (minor units)", placeholder: "2500", text: $model.amountText, keyboardType: .numberPad)
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
