import SwiftUI

struct ExpensesView: View {
  @Environment(\.appPalette) private var palette
  @Bindable var viewModel: ExpensesViewModel
  let deps: AppDependencies
  var onOpenSettings: () -> Void

  var body: some View {
    TerminalScreen {
      VStack(alignment: .leading, spacing: 20) {
        SectionHeader(
          title: "expenses",
          subtitle: viewModel.periodSubtitle ?? "analytics and spend by period",
          subtitleLoading: isPeriodContentLoading && viewModel.periodSubtitle == nil
        )

        if let error = viewModel.errorMessage {
          ErrorBanner(message: error) { Task { await viewModel.load() } }
        }

        TerminalSegmentedControl(selection: $viewModel.periodKey, options: ExpensePeriodKey.allCases)

        if viewModel.needsPrimarySchedule {
          EmptyStateCard(
            message: "> set a primary pay schedule.",
            footnote: "> required for pay-period view."
          )
          TerminalButton(title: "open settings", action: onOpenSettings)
        } else {
          heroCard
          if viewModel.periodKey == .lastPeriod {
            extraStatsRow
          }
          quickActions
          expenseList
        }
      }
    }
    .refreshable { await viewModel.load(force: true) }
    .task { await viewModel.load() }
    .navigationDestination(for: ExpensesRoute.self) { route in
      switch route {
      case .recurring:
        RecurringExpensesView(deps: deps)
      case .planned:
        PlannedExpensesView(deps: deps)
      case .earlyPay:
        EarlyPayView(deps: deps)
      }
    }
    .sheet(isPresented: $viewModel.showExpenseForm) {
      ExpenseFormSheet(deps: deps, knownTags: viewModel.formTags) {
        viewModel.showExpenseForm = false
        Task { await viewModel.load() }
      }
      .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $viewModel.showEditAmountForm) {
      if let id = viewModel.editAmountExpenseId,
         let amount = viewModel.editAmountInitial,
         let currency = viewModel.editAmountCurrency {
        ExpenseAmountFormSheet(
          deps: deps,
          expenseId: id,
          initialAmount: amount,
          currency: currency
        ) {
          viewModel.showEditAmountForm = false
          Task { await viewModel.load() }
        }
        .presentationDetents([.medium])
      }
    }
    .confirmationDialog("Delete expense?", isPresented: Binding(
      get: { viewModel.deleteExpenseId != nil },
      set: { if !$0 { viewModel.deleteExpenseId = nil } }
    )) {
      Button("delete", role: .destructive) {
        if let id = viewModel.deleteExpenseId {
          Task { await viewModel.deleteExpense(id: id) }
        }
      }
    }
  }

  private var heroCard: some View {
    Group {
      if isPeriodContentLoading {
        ExpenseHeroSkeleton()
      } else {
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
    }
  }

  private var extraStatsRow: some View {
    Group {
      if isPeriodContentLoading {
        ExpenseStatsSkeleton()
      } else {
        HStack(spacing: 8) {
          extraStatCard(
            title: "> extra spent",
            value: Text(MoneyFormatter.format(
              viewModel.periodView?.extraSpend ?? 0,
              currency: deps.displayCurrency
            ))
            .font(AppFont.mono(size: 20, weight: .medium))
            .foregroundStyle(isExtraOverLimit ? palette.danger : palette.text),
            footnote: extraLimitFootnote
          )

          extraStatCard(
            title: "> planned used",
            value: Text(plannedUsedLabel)
              .font(AppFont.mono(size: 20, weight: .medium))
              .foregroundStyle(palette.text),
            footnote: nil
          )
        }
      }
    }
  }

  private var isExtraOverLimit: Bool {
    guard let periodView = viewModel.periodView,
          let limit = periodView.extraSpendLimitConverted else {
      return false
    }
    return (periodView.extraSpend ?? 0) > limit
  }

  private var extraLimitFootnote: String? {
    guard let limit = viewModel.periodView?.extraSpendLimitConverted else { return nil }
    return "> limit \(MoneyFormatter.format(limit, currency: deps.displayCurrency))"
  }

  private var plannedUsedLabel: String {
    if let percent = viewModel.periodView?.plannedUsedPercent {
      return "\(percent)%"
    }
    return "—"
  }

  private func extraStatCard<Content: View>(
    title: String,
    value: Content,
    footnote: String?
  ) -> some View {
    TerminalCard {
      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.muted)
        value
        if let footnote {
          Text(footnote)
            .font(AppFont.mono(size: 11))
            .foregroundStyle(palette.muted)
        }
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
        Task {
          await viewModel.loadFormTags()
          viewModel.showExpenseForm = true
        }
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

      if isPeriodContentLoading {
        ExpensePeriodListSkeleton()
      } else if viewModel.periodItems.isEmpty {
        EmptyStateCard(message: "> no expenses in this period.")
      } else {
        ForEach(viewModel.periodItems) { item in
          expenseItemRow(item)
        }
      }
    }
  }

  private func expenseItemRow(_ item: ProjectionExpenseItem) -> some View {
    let canMutate = viewModel.canEdit(item)

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
    .contentShape(Rectangle())
    .onTapGesture {
      if canMutate {
        viewModel.beginEditAmount(for: item)
      }
    }
    .contextMenu {
      if canMutate {
        Button("edit amount") {
          viewModel.beginEditAmount(for: item)
        }
        Button("delete", role: .destructive) {
          if let id = item.itemId {
            viewModel.deleteExpenseId = id
          }
        }
      }
    }
  }

  private var isPeriodContentLoading: Bool {
    viewModel.isLoadingPeriod || viewModel.isLoadingSharedContext
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
      AmountTextField(text: $model.amountText, placeholder: "45.00")
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

  init(
    deps: AppDependencies,
    expenseId: String,
    initialAmount: Int,
    currency: CurrencyCode,
    onSaved: @escaping () -> Void
  ) {
    _model = State(
      initialValue: ExpenseAmountFormModel(
        deps: deps,
        expenseId: expenseId,
        initialAmount: initialAmount,
        currency: currency
      )
    )
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(title: "edit amount", isSaving: isSaving, canSave: model.canSave, onSave: { Task { await save() } }) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      AmountTextField(text: $model.amountText, placeholder: "45.00")
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
