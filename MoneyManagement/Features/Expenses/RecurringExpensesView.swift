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
        SectionHeader(title: "recurring", subtitle: "subscription and recurring payments")

        if let error = viewModel.errorMessage {
          ErrorBanner(message: error) { Task { await viewModel.load() } }
        }

        TerminalButton(title: "+ add recurring") {
          viewModel.editing = nil
          viewModel.showForm = true
        }

        if viewModel.items.isEmpty && !viewModel.isLoading {
          EmptyStateCard(message: "> no recurring expenses yet.")
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
    .confirmationDialog("Delete recurring expense?", isPresented: Binding(
      get: { viewModel.deleteTarget != nil },
      set: { if !$0 { viewModel.deleteTarget = nil } }
    )) {
      Button("delete", role: .destructive) {
        if let target = viewModel.deleteTarget {
          Task { await viewModel.delete(target) }
        }
      }
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
            TerminalBadge(text: "sub", style: .muted)
          }
          Spacer()
          MoneyLabel(amount: item.amount, currency: item.currency, displayCurrency: deps.displayCurrency, rates: deps.rates)
        }

        Text("> \(item.frequency.label) · anchor \(item.anchorDate)")
          .font(AppFont.mono(size: 11))
          .foregroundStyle(palette.muted)

        let dates = PayPeriodLogic.getUpcomingPayDates(
          schedule: PayPeriodLogic.scheduleInput(from: item),
          count: 2
        )
        if !dates.isEmpty {
          Text("> next: \(dates.joined(separator: ", "))")
            .font(AppFont.mono(size: 11))
            .foregroundStyle(palette.muted)
        }

        TerminalTagFlow(tags: item.tags)

        HStack(spacing: 8) {
          Button("edit") {
            viewModel.editing = item
            viewModel.showForm = true
          }
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.accent)

          Button("delete") {
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
      title: model.isEditing ? "edit recurring" : "add recurring",
      isSaving: isSaving,
      canSave: model.canSave,
      onSave: { Task { await save() } }
    ) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      TerminalTextField(label: "name", placeholder: "netflix", text: $model.name)
      TerminalTextField(label: "anchor date", placeholder: "YYYY-MM-DD", text: $model.anchorDate, keyboardType: .numbersAndPunctuation)
      FrequencyPicker(selection: $model.frequency)
      AmountTextField(text: $model.amountText, placeholder: "1500.00")
      CurrencyPicker(selection: $model.currency)
      TagsInputField(tagsText: $model.tagsText, knownTags: knownTags)
      SubscriptionToggle(isSubscription: $model.isSubscription)
      TerminalTextField(label: "last payment date (optional)", placeholder: "YYYY-MM-DD", text: $model.lastPaymentDate, keyboardType: .numbersAndPunctuation)
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
