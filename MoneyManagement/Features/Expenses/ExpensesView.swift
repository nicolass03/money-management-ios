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
          title: L10n.t("expenses"),
          subtitle: viewModel.periodSubtitle ?? L10n.t("analytics and spend by period"),
          subtitleLoading: isPeriodContentLoading && viewModel.periodSubtitle == nil
        )

        if let error = viewModel.errorMessage {
          ErrorBanner(message: error) { Task { await viewModel.load() } }
        }

        TerminalSegmentedControl(selection: $viewModel.periodKey, options: ExpensePeriodKey.allCases)

        if viewModel.needsPrimarySchedule {
          EmptyStateCard(
            message: L10n.t("> set a primary pay schedule."),
            footnote: L10n.t("> required for pay-period view.")
          )
          TerminalButton(title: L10n.t("open settings"), action: onOpenSettings)
        } else {
          heroCard
          extraSpentCard
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
    .confirmationDialog(L10n.t("Delete expense?"), isPresented: Binding(
      get: { viewModel.deleteExpenseId != nil },
      set: { if !$0 { viewModel.deleteExpenseId = nil } }
    )) {
      Button(L10n.t("delete"), role: .destructive) {
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
            Text(L10n.t("> total spent"))
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

  private var extraSpentCard: some View {
    Group {
      if isPeriodContentLoading {
        ExpenseHeroSkeleton()
      } else {
        TerminalCard {
          VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("> extra spent"))
              .font(AppFont.mono(size: 12))
              .foregroundStyle(palette.muted)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text(deps.formatMoney(viewModel.extraSpent, currency: deps.displayCurrency))
                .font(AppFont.mono(size: 28, weight: .medium))
                .foregroundStyle(extraSpentColor)

              if let limit = viewModel.extraSpentLimit {
                Text(String(format: L10n.t("> / %@ limit"), deps.formatMoney(limit, currency: deps.displayCurrency)))
                  .font(AppFont.mono(size: 11))
                  .foregroundStyle(palette.muted)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  // Yellow within 30% of the limit (>=70% used), red within 8% or over it (>=92% used).
  private var extraSpentColor: Color {
    guard let usage = viewModel.extraSpentUsage else { return palette.text }
    if usage >= 0.92 { return palette.danger }
    if usage >= 0.70 { return palette.warning }
    return palette.text
  }

  private var quickActions: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
      NavigationLink(value: ExpensesRoute.recurring) {
        quickActionLabel(title: L10n.t("recurring"), systemImage: "arrow.clockwise")
      }
      .buttonStyle(.plain)

      NavigationLink(value: ExpensesRoute.planned) {
        quickActionLabel(title: L10n.t("one-time"), systemImage: "calendar")
      }
      .buttonStyle(.plain)

      Button {
        Task {
          await viewModel.loadFormTags()
          viewModel.showExpenseForm = true
        }
      } label: {
        quickActionLabel(title: L10n.t("add"), systemImage: "plus")
      }
      .buttonStyle(.plain)

      NavigationLink(value: ExpensesRoute.earlyPay) {
        quickActionLabel(title: L10n.t("early pay"), systemImage: "bolt")
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
      SectionHeader(title: L10n.t("spendings"))

      if isPeriodContentLoading {
        ExpensePeriodListSkeleton()
      } else if viewModel.periodItems.isEmpty {
        EmptyStateCard(message: L10n.t("> no expenses in this period."))
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
        HStack(spacing: 6) {
          Text(item.name)
            .font(AppFont.mono(size: 14))
            .foregroundStyle(palette.text)
            .lineLimit(1)

          if viewModel.canDelete(item) {
            TerminalBadge(text: L10n.t("extra"), style: .warning)
          }
        }

        Text(L10n.t(" · "))
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
            TerminalBadge(text: L10n.t("subscription"), style: .muted)
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
        Button(L10n.t("edit amount")) {
          viewModel.beginEditAmount(for: item)
        }
        Button(L10n.t("delete"), role: .destructive) {
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
    FormSheet(title: L10n.t("add expense"), isSaving: isSaving, canSave: model.canSave, onSave: { Task { await save() } }) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      TerminalTextField(label: L10n.t("name"), placeholder: L10n.t("groceries"), text: $model.name)
      AmountTextField(text: $model.amountText, placeholder: "45.00")
      AccountPicker(accounts: model.accounts, selection: $model.accountId)
      TerminalTextField(label: L10n.t("date"), placeholder: L10n.t("YYYY-MM-DD"), text: $model.date, keyboardType: .numbersAndPunctuation)
      TagsInputField(tagsText: $model.tagsText, knownTags: knownTags)
      SubscriptionToggle(isSubscription: $model.isSubscription)
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
    FormSheet(title: L10n.t("edit amount"), isSaving: isSaving, canSave: model.canSave, onSave: { Task { await save() } }) {
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
