import SwiftUI

struct RecurringExpensesView: View {
  @Environment(\.appPalette) private var palette
  @State private var viewModel: RecurringExpensesViewModel
  let deps: AppDependencies

  init(deps: AppDependencies) {
    self.deps = deps
    _viewModel = State(initialValue: RecurringExpensesViewModel(deps: deps))
  }

  var body: some View {
    TerminalScreen {
      VStack(alignment: .leading, spacing: 20) {
        SectionHeader(title: L10n.t("recurring"), subtitle: L10n.t("subscription and recurring payments"))

        if let error = viewModel.errorMessage {
          ErrorBanner(message: error) { Task { await viewModel.load() } }
        }

        TerminalButton(title: L10n.t("+ add recurring")) {
          viewModel.editing = nil
          viewModel.showForm = true
        }

        if !viewModel.subscriptions.isEmpty {
          TerminalButton(title: L10n.t("cancel reminder")) {
            viewModel.showCancelReminderSheet = true
          }
        }

        if viewModel.items.isEmpty && !viewModel.isLoading {
          EmptyStateCard(message: L10n.t("> no recurring expenses yet."))
        } else {
          ForEach(viewModel.items) { item in
            recurringCard(item)
          }
        }
      }
    }
    .overlay { if viewModel.isLoading { LoadingOverlay() } }
    .refreshable { await viewModel.load(force: true) }
    .task { await viewModel.load() }
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $viewModel.showForm) {
      RecurringExpenseFormSheet(deps: deps, editing: viewModel.editing, knownTags: viewModel.tags) {
        viewModel.showForm = false
        Task { await viewModel.load() }
      }
      .presentationDetents([.medium, .large])
    }
    .confirmationDialog(L10n.t("Delete recurring expense?"), isPresented: Binding(
      get: { viewModel.deleteTarget != nil },
      set: { if !$0 { viewModel.deleteTarget = nil } }
    )) {
      Button(L10n.t("delete"), role: .destructive) {
        if let target = viewModel.deleteTarget {
          Task { await viewModel.delete(target) }
        }
      }
    }
    .sheet(isPresented: $viewModel.showCancelReminderSheet) {
      CancelReminderSheet(subscriptions: viewModel.subscriptions) { sub in
        Task { await viewModel.setCancelReminder(sub, enabled: !sub.cancelReminderEnabled) }
      }
      .presentationDetents([.medium, .large])
    }
  }

  private func recurringCard(_ item: RecurringExpenseWithTags) -> some View {
    TerminalCard {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(item.name)
            .font(AppFont.mono(size: 14, weight: .medium))
            .foregroundStyle(palette.text)
          if item.isSubscription {
            TerminalBadge(text: L10n.t("sub"), style: .muted)
          }
          Spacer()
          MoneyLabel(amount: item.amount, currency: item.currency, displayCurrency: deps.displayCurrency, rates: deps.rates)
        }

        Text(String(format: L10n.t("> %@ · anchor %@"), item.frequency.label, item.anchorDate))
          .font(AppFont.mono(size: 11))
          .foregroundStyle(palette.muted)

        let dates = PayPeriodLogic.getUpcomingPayDates(
          schedule: PayPeriodLogic.scheduleInput(from: item),
          count: 2
        )
        if !dates.isEmpty {
          Text(String(format: L10n.t("> next: %@"), dates.joined(separator: ", ")))
            .font(AppFont.mono(size: 11))
            .foregroundStyle(palette.muted)
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

private struct RecurringExpenseFormSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: RecurringExpenseFormModel
  @State private var isSaving = false
  @State private var errorMessage: String?
  let knownTags: [String]
  let onSaved: () -> Void

  init(deps: AppDependencies, editing: RecurringExpenseWithTags?, knownTags: [String], onSaved: @escaping () -> Void) {
    _model = State(initialValue: RecurringExpenseFormModel(deps: deps, editing: editing))
    self.knownTags = knownTags
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(
      title: model.isEditing ? L10n.t("edit recurring") : L10n.t("add recurring"),
      isSaving: isSaving,
      canSave: model.canSave,
      onSave: { Task { await save() } }
    ) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      TerminalTextField(label: L10n.t("name"), placeholder: L10n.t("netflix"), text: $model.name)
      TerminalTextField(label: L10n.t("anchor date"), placeholder: L10n.t("YYYY-MM-DD"), text: $model.anchorDate, keyboardType: .numbersAndPunctuation)
      FrequencyPicker(selection: $model.frequency)
      AmountTextField(text: $model.amountText, placeholder: "1500.00")
      AccountPicker(accounts: model.accounts, selection: $model.accountId, includeAutoOption: true)
      // A pinned account locks the currency to follow it; "auto" keeps the free currency picker.
      if !model.currencyLocked {
        CurrencyPicker(selection: $model.currency)
      }
      TagsInputField(tagsText: $model.tagsText, knownTags: knownTags)
      SubscriptionToggle(isSubscription: $model.isSubscription)
      TerminalTextField(label: L10n.t("last payment date (optional)"), placeholder: L10n.t("YYYY-MM-DD"), text: $model.lastPaymentDate, keyboardType: .numbersAndPunctuation)
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

/// Lets the user flag (or unflag) a subscription for cancellation reminders. Tapping a row toggles
/// it; the device then schedules 9am-local notifications 5 and 2 days before its next charge.
private struct CancelReminderSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.appPalette) private var palette
  let subscriptions: [RecurringExpenseWithTags]
  let onToggle: (RecurringExpenseWithTags) -> Void

  var body: some View {
    NavigationStack {
      TerminalScreen {
        VStack(alignment: .leading, spacing: 16) {
          SectionHeader(
            title: L10n.t("cancel a subscription"),
            subtitle: L10n.t("tap a subscription to toggle a cancellation reminder")
          )

          if subscriptions.isEmpty {
            EmptyStateCard(message: L10n.t("> no subscriptions to remind about."))
          } else {
            ForEach(subscriptions) { sub in
              Button {
                onToggle(sub)
              } label: {
                subscriptionRow(sub)
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.t("done")) { dismiss() }
        }
      }
    }
  }

  private func subscriptionRow(_ sub: RecurringExpenseWithTags) -> some View {
    TerminalCard {
      HStack(spacing: 8) {
        VStack(alignment: .leading, spacing: 4) {
          Text(sub.name)
            .font(AppFont.mono(size: 14, weight: .medium))
            .foregroundStyle(palette.text)
          if let next = PayPeriodLogic.getUpcomingPayDates(
            schedule: PayPeriodLogic.scheduleInput(from: sub),
            count: 1
          ).first {
            Text(String(format: L10n.t("next charge: %@"), next))
              .font(AppFont.mono(size: 11))
              .foregroundStyle(palette.muted)
          }
        }
        Spacer()
        if sub.cancelReminderEnabled {
          TerminalBadge(text: L10n.t("reminder set"), style: .accent)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
