import SwiftUI

struct EarlyPayView: View {
  @Environment(\.appPalette) private var palette
  @State private var viewModel: EarlyPayViewModel
  let deps: AppDependencies

  init(deps: AppDependencies) {
    self.deps = deps
    _viewModel = State(initialValue: EarlyPayViewModel(deps: deps))
  }

  var body: some View {
    TerminalScreen {
      VStack(alignment: .leading, spacing: 20) {
        SectionHeader(
          title: "early pay",
          subtitle: "mark upcoming charges as paid in this period"
        )

        if let error = viewModel.errorMessage {
          ErrorBanner(message: error) { Task { await viewModel.load() } }
        }

        if viewModel.items.isEmpty && !viewModel.isLoading {
          EmptyStateCard(message: "> no upcoming charges in the next 30 days.")
        } else {
          ForEach(viewModel.items) { item in
            earlyPayRow(item)
          }
        }
      }
    }
    .overlay { if viewModel.isLoading { LoadingOverlay() } }
    .refreshable { await viewModel.load(force: true) }
    .task { await viewModel.load() }
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $viewModel.showForm) {
      if let item = viewModel.selectedItem {
        EarlyPayFormSheet(deps: deps, item: item) {
          viewModel.showForm = false
          Task { await viewModel.load() }
        }
        .presentationDetents([.medium])
      }
    }
  }

  private func earlyPayRow(_ item: PayableFutureItem) -> some View {
    Button {
      viewModel.selectedItem = item
      viewModel.showForm = true
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        Text(item.name)
          .font(AppFont.mono(size: 14))
          .foregroundStyle(palette.text)
          .lineLimit(1)

        Text(" · ")
          .font(AppFont.mono(size: 14))
          .foregroundStyle(palette.muted)

        Text("due \(item.scheduledDate)")
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.muted)
          .lineLimit(1)

        Spacer(minLength: 8)

        Text(deps.formatMoney(item.amount, currency: item.currency))
          .font(AppFont.mono(size: 13, weight: .medium))
          .foregroundStyle(palette.text)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(palette.surface)
      .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
    }
    .buttonStyle(.plain)
  }
}

@Observable
@MainActor
final class EarlyPayViewModel {
  private let deps: AppDependencies

  var items: [PayableFutureItem] = []
  var isLoading = false
  var errorMessage: String?
  var selectedItem: PayableFutureItem?
  var showForm = false

  init(deps: AppDependencies) {
    self.deps = deps
  }

  func load(force: Bool = false) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      if force {
        deps.invalidateAll()
      }

      try await deps.refreshSharedContext()
      async let expensesTask = deps.dataStore.getExpenses { [deps] in
        try await deps.api.getExpenses()
      }
      async let recurringTask = deps.dataStore.getRecurringExpenses { [deps] in
        try await deps.api.getRecurringExpenses()
      }
      async let plannedTask = deps.dataStore.getPlannedExpenses { [deps] in
        try await deps.api.getPlannedExpenses()
      }
      let expenses = try await expensesTask
      let recurring = try await recurringTask
      let planned = try await plannedTask
      items = UpcomingPayableLogic.getUpcomingPayableItems(
        expenses: expenses,
        recurringExpenses: recurring,
        plannedExpenses: planned
      )
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

struct EarlyPayFormSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: EarlyPayFormModel
  @State private var isSaving = false
  @State private var errorMessage: String?
  let onSaved: () -> Void

  init(deps: AppDependencies, item: PayableFutureItem, onSaved: @escaping () -> Void) {
    _model = State(initialValue: EarlyPayFormModel(deps: deps, item: item))
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(title: "mark early pay", isSaving: isSaving, canSave: model.canSave, onSave: { Task { await save() } }) {
      if let errorMessage { ErrorBanner(message: errorMessage) }
      TerminalTextField(label: "paid date", placeholder: "YYYY-MM-DD", text: $model.paidDate, keyboardType: .numbersAndPunctuation)
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
