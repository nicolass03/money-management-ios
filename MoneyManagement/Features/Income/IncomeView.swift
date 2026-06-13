import SwiftUI

struct IncomeView: View {
  @Environment(\.appPalette) private var palette
  @Bindable var viewModel: IncomeViewModel
  let deps: AppDependencies

  var body: some View {
    TerminalScreen {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          SectionHeader(title: "income", subtitle: "pay schedules and entries")
          Spacer()
          if viewModel.isLoadingEntries || deps.isLoadingContext {
            Skeleton()
              .frame(width: 72, height: 20)
          } else if !viewModel.displayedEntries.isEmpty {
            TerminalBadge(text: deps.formatMoney(viewModel.totalIncome, currency: deps.displayCurrency), style: .accent)
          }
        }

        if let error = viewModel.errorMessage {
          ErrorBanner(message: error) { Task { await viewModel.load() } }
        }

        TerminalSegmentedControl(selection: $viewModel.section, options: IncomeSection.allCases)

        switch viewModel.section {
        case .schedules:
          schedulesSection
        case .entries:
          entriesSection
        }
      }
    }
    .refreshable { await viewModel.load(force: true) }
    .task { await viewModel.load() }
    .sheet(isPresented: $viewModel.showScheduleForm) {
      IncomeScheduleFormSheet(deps: deps, editing: viewModel.scheduleSheet) {
        viewModel.showScheduleForm = false
        Task { await viewModel.load() }
      }
      .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $viewModel.showIncomeForm) {
      IncomeEntryFormSheet(deps: deps, editing: viewModel.incomeSheet) {
        viewModel.showIncomeForm = false
        Task { await viewModel.load() }
      }
      .presentationDetents([.medium, .large])
    }
    .confirmationDialog("Delete schedule?", isPresented: Binding(
      get: { viewModel.deleteScheduleTarget != nil },
      set: { if !$0 { viewModel.deleteScheduleTarget = nil } }
    )) {
      Button("delete", role: .destructive) {
        if let target = viewModel.deleteScheduleTarget {
          Task { await viewModel.deleteSchedule(target) }
        }
      }
    }
    .confirmationDialog("Delete income?", isPresented: Binding(
      get: { viewModel.deleteIncomeTarget != nil },
      set: { if !$0 { viewModel.deleteIncomeTarget = nil } }
    )) {
      Button("delete", role: .destructive) {
        if let target = viewModel.deleteIncomeTarget {
          Task { await viewModel.deleteIncome(target) }
        }
      }
    }
  }

  private var schedulesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !viewModel.isLoadingSchedules && !deps.isLoadingContext {
        TerminalButton(title: "+ add schedule") {
          viewModel.scheduleSheet = nil
          viewModel.showScheduleForm = true
        }
      }

      if viewModel.isLoadingSchedules || deps.isLoadingContext {
        CardListSkeleton(count: 2, label: "loading pay schedules")
      } else if viewModel.schedules.isEmpty {
        EmptyStateCard(message: "> no pay schedules yet.")
      } else {
        ForEach(viewModel.schedules) { schedule in
          scheduleCard(schedule)
        }
      }
    }
  }

  private func scheduleCard(_ schedule: IncomePaySchedule) -> some View {
    TerminalCard {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text(schedule.name)
            .font(AppFont.mono(size: 14, weight: .medium))
            .foregroundStyle(palette.text)
          Spacer()
          MoneyLabel(amount: schedule.amount, currency: schedule.currency, displayCurrency: deps.displayCurrency, rates: deps.rates)
        }

        Text("> \(schedule.frequency.label) · anchor \(schedule.anchorDate)")
          .font(AppFont.mono(size: 11))
          .foregroundStyle(palette.muted)

        let dates = PayPeriodLogic.getUpcomingPayDates(
          schedule: PayPeriodLogic.scheduleInput(from: schedule),
          count: 4
        )
        if !dates.isEmpty {
          Text("> next: \(dates.joined(separator: ", "))")
            .font(AppFont.mono(size: 11))
            .foregroundStyle(palette.muted)
        }

        HStack(spacing: 8) {
          Button("edit") {
            viewModel.scheduleSheet = schedule
            viewModel.showScheduleForm = true
          }
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.accent)

          Button("delete") {
            viewModel.deleteScheduleTarget = schedule
          }
          .font(AppFont.mono(size: 12))
          .foregroundStyle(palette.danger)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var entriesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !viewModel.isLoadingEntries && !deps.isLoadingContext {
        TerminalButton(title: "+ add income") {
          viewModel.incomeSheet = nil
          viewModel.showIncomeForm = true
        }
      }

      if viewModel.isLoadingEntries || deps.isLoadingContext {
        CardListSkeleton(count: 3, label: "loading income entries")
      } else if viewModel.displayedEntries.isEmpty {
        EmptyStateCard(message: "> no income entries yet.")
      } else {
        ForEach(viewModel.displayedEntries) { entry in
          entryRow(entry)
        }
      }
    }
  }

  private func entryRow(_ entry: Income) -> some View {
    TerminalCard {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(entry.name)
                .font(AppFont.mono(size: 14))
                .foregroundStyle(palette.text)
              if !entry.isManual {
                TerminalBadge(text: "scheduled", style: .muted)
              }
            }
            Text("> \(entry.date) · \(entry.source.rawValue)")
              .font(AppFont.mono(size: 11))
              .foregroundStyle(palette.muted)
          }
          Spacer()
          MoneyLabel(amount: entry.amount, currency: entry.currency, displayCurrency: deps.displayCurrency, rates: deps.rates)
        }

        if entry.isManual {
          HStack(spacing: 8) {
            Button("edit") {
              viewModel.incomeSheet = entry
              viewModel.showIncomeForm = true
            }
            .font(AppFont.mono(size: 12))
            .foregroundStyle(palette.accent)

            Button("delete") {
              viewModel.deleteIncomeTarget = entry
            }
            .font(AppFont.mono(size: 12))
            .foregroundStyle(palette.danger)
          }
        }
      }
    }
  }
}

private struct IncomeScheduleFormSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: IncomeScheduleFormModel
  @State private var isSaving = false
  @State private var errorMessage: String?
  let onSaved: () -> Void

  init(deps: AppDependencies, editing: IncomePaySchedule?, onSaved: @escaping () -> Void) {
    _model = State(initialValue: IncomeScheduleFormModel(deps: deps, editing: editing))
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(
      title: model.isEditing ? "edit schedule" : "add schedule",
      isSaving: isSaving,
      canSave: model.canSave,
      onSave: { Task { await save() } }
    ) {
      if let errorMessage {
        ErrorBanner(message: errorMessage)
      }
      TerminalTextField(label: "name", placeholder: "salary", text: $model.name)
      TerminalTextField(label: "anchor date", placeholder: "YYYY-MM-DD", text: $model.anchorDate, keyboardType: .numbersAndPunctuation)
      FrequencyPicker(selection: $model.frequency)
      TerminalTextField(label: "amount (minor units)", placeholder: "100000", text: $model.amountText, keyboardType: .numberPad)
      CurrencyPicker(selection: $model.currency)
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

private struct IncomeEntryFormSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: IncomeEntryFormModel
  @State private var isSaving = false
  @State private var errorMessage: String?
  let onSaved: () -> Void

  init(deps: AppDependencies, editing: Income?, onSaved: @escaping () -> Void) {
    _model = State(initialValue: IncomeEntryFormModel(deps: deps, editing: editing))
    self.onSaved = onSaved
  }

  var body: some View {
    FormSheet(
      title: model.isEditing ? "edit income" : "add income",
      isSaving: isSaving,
      canSave: model.canSave,
      onSave: { Task { await save() } }
    ) {
      if let errorMessage {
        ErrorBanner(message: errorMessage)
      }
      TerminalTextField(label: "name", placeholder: "bonus", text: $model.name)
      TerminalTextField(label: "date", placeholder: "YYYY-MM-DD", text: $model.date, keyboardType: .numbersAndPunctuation)
      TerminalTextField(label: "amount (minor units)", placeholder: "50000", text: $model.amountText, keyboardType: .numberPad)
      CurrencyPicker(selection: $model.currency)
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
