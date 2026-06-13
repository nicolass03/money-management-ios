import SwiftUI

struct ProjectionsView: View {
  @Environment(\.appPalette) private var palette
  @Bindable var viewModel: ProjectionsViewModel
  let deps: AppDependencies
  var onOpenSettings: () -> Void

  var body: some View {
    TerminalScreen {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          SectionHeader(title: "projections", subtitle: "cash flow by pay period")
          Spacer()
          if viewModel.isLoading || deps.isLoadingContext {
            Skeleton()
              .frame(width: 80, height: 20)
          } else if let cumulative = viewModel.latestCumulativeFree, let response = viewModel.response {
            TerminalBadge(
              text: MoneyFormatter.format(cumulative, currency: response.displayCurrency),
              style: cumulative >= 0 ? .success : .danger
            )
          }
        }

        if let error = viewModel.errorMessage, !viewModel.needsPrimarySchedule {
          ErrorBanner(message: error) { Task { await viewModel.load() } }
        }

        if (viewModel.isLoading || deps.isLoadingContext) && viewModel.response == nil {
          ProjectionsListSkeleton()
        } else if viewModel.needsPrimarySchedule {
          EmptyStateCard(
            message: "> no primary pay schedule.",
            footnote: "> configure in settings to see projections."
          )
          TerminalButton(title: "open settings", action: onOpenSettings)
        } else if let response = viewModel.response {
          Text("> \(response.primarySchedule.name) · \(response.displayCurrency.label)")
            .font(AppFont.mono(size: 12))
            .foregroundStyle(palette.muted)

          if viewModel.displayRows.isEmpty {
            EmptyStateCard(message: "> no projection rows.")
          } else {
            ForEach(viewModel.displayRows) { row in
              projectionRow(row, displayCurrency: response.displayCurrency, rates: response.rates)
            }
          }
        }
      }
    }
    .refreshable { await viewModel.load(force: true) }
    .task { await viewModel.load() }
  }

  private func projectionRow(_ row: ProjectionRow, displayCurrency: CurrencyCode, rates: ExchangeRates) -> some View {
    let isExpanded = viewModel.expandedPayDates.contains(row.payDate)
    let isCurrent = isCurrentPeriod(row)

    return VStack(alignment: .leading, spacing: 12) {
      Button { viewModel.toggleExpanded(row) } label: {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(formatPeriodEndLabel(row.endDate))
              .font(AppFont.mono(size: 14, weight: .medium))
              .foregroundStyle(palette.text)

            Spacer(minLength: 12)

            Text(formatPeriodRange(row.startDate, row.endDate))
              .font(AppFont.mono(size: 11))
              .foregroundStyle(palette.muted)
              .multilineTextAlignment(.trailing)
          }

          HStack(alignment: .bottom, spacing: 12) {
            projectionAmountColumn(
              label: "out",
              amount: row.expenseTotal,
              currency: displayCurrency,
              alignment: .leading
            )

            Spacer(minLength: 12)

            projectionAmountColumn(
              label: "free",
              amount: row.periodFree,
              currency: displayCurrency,
              alignment: .trailing
            )
          }
        }
      }
      .buttonStyle(.plain)

      if isExpanded {
        Divider().overlay(palette.border)
        ForEach(row.expenseItems) { item in
          HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(item.name)
              .font(AppFont.mono(size: 12))
              .foregroundStyle(palette.text)
              .lineLimit(1)

            Text(" · ")
              .font(AppFont.mono(size: 12))
              .foregroundStyle(palette.muted)

            Text(item.date)
              .font(AppFont.mono(size: 11))
              .foregroundStyle(palette.muted)
              .lineLimit(1)

            Spacer(minLength: 8)

            MoneyLabel(
              amount: item.convertedAmount,
              currency: displayCurrency,
              size: 12,
              weight: .medium
            )
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 4)
        }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(isCurrent ? palette.surfaceElevated : palette.surface)
    .overlay {
      Rectangle()
        .stroke(
          isCurrent ? palette.accent.opacity(0.55) : palette.border,
          lineWidth: isCurrent ? 1.5 : 1
        )
    }
    .shadow(color: isCurrent ? palette.glow : palette.glowPulse, radius: isCurrent ? 12 : 8)
  }

  private func isCurrentPeriod(_ row: ProjectionRow) -> Bool {
    let today = PayPeriodLogic.todayISO()
    return today >= row.startDate && today <= row.endDate
  }

  private func projectionAmountColumn(
    label: String,
    amount: Int,
    currency: CurrencyCode,
    alignment: HorizontalAlignment
  ) -> some View {
    VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 4) {
      Text("> \(label)")
        .font(AppFont.mono(size: 10))
        .foregroundStyle(palette.muted)

      MoneyLabel(
        amount: amount,
        currency: currency,
        size: 22,
        weight: .medium
      )
    }
  }

  private func formatPeriodEndLabel(_ iso: String) -> String {
    guard let date = Self.isoDateFormatter.date(from: iso) else { return iso }
    return Self.periodEndFormatter.string(from: date)
  }

  private func formatPeriodRange(_ start: String, _ end: String) -> String {
    guard
      let startDate = Self.isoDateFormatter.date(from: start),
      let endDate = Self.isoDateFormatter.date(from: end)
    else {
      return "\(start) – \(end)"
    }

    let startLabel = Self.periodRangeFormatter.string(from: startDate)
    let endLabel = Self.periodRangeFormatter.string(from: endDate)
    return "\(startLabel) – \(endLabel)"
  }

  private static let isoDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter
  }()

  private static let periodEndFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "MMM, dd"
    formatter.timeZone = TimeZone.current
    return formatter
  }()

  private static let periodRangeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "MMM d, yyyy"
    formatter.timeZone = TimeZone.current
    return formatter
  }()
}
