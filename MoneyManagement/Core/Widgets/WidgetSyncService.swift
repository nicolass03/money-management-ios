import Foundation
import SpendflyShared
import WidgetKit

@MainActor
enum WidgetSyncService {
    static func sync(deps: AppDependencies, language: String, theme: String, themeMode: String) async {
        guard deps.isAuthenticated else {
            clear(language: language, theme: theme, themeMode: themeMode)
            return
        }

        do {
            try await deps.refreshSharedContext()
        } catch {
            return
        }

        let displayCurrency = SpendflyShared.CurrencyCode(rawValue: deps.displayCurrency.rawValue) ?? .eur
        let hasPrimarySchedule = deps.settings?.primaryScheduleId != nil

        async let monthTask = fetchPeriod(deps: deps, period: .lastMonth)
        async let periodTask = fetchPeriod(deps: deps, period: .lastPeriod)

        let monthView = await monthTask
        let periodView = await periodTask

        let monthSpent = monthView?.totalSpend ?? 0
        let monthLabel = periodLabel(monthView?.period)

        let extraSpent = periodView?.extraSpent ?? 0
        let extraLimit: Int? = {
            guard periodView?.isPayPeriod == true,
                  let limit = periodView?.extraSpentLimit,
                  limit > 0 else { return nil }
            return limit
        }()

        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            displayCurrency: displayCurrency,
            language: language,
            theme: theme,
            themeMode: themeMode,
            monthSpent: monthSpent,
            monthPeriodLabel: monthLabel,
            extraSpent: extraSpent,
            extraSpentLimit: extraLimit,
            payPeriodLabel: periodLabel(periodView?.period),
            hasPrimarySchedule: hasPrimarySchedule,
            isSignedIn: true
        )

        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear(language: String, theme: String, themeMode: String) {
        WidgetSnapshotStore.save(.signedOut(language: language, theme: theme, themeMode: themeMode))
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func fetchPeriod(deps: AppDependencies, period: ExpensePeriodKey) async -> ExpensePeriodViewResponse? {
        do {
            return try await deps.api.getExpensePeriodView(period: period)
        } catch {
            if period == .lastPeriod, deps.settings?.primaryScheduleId == nil {
                return nil
            }
            return nil
        }
    }

    private static func periodLabel(_ period: PayPeriodResponse?) -> String {
        guard let period else { return "" }
        return "\(period.startDate) → \(period.endDate)"
    }
}
