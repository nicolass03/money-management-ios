import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    private let deps: AppDependencies

    var language: AppLanguage = .en
    var displayCurrency: CurrencyCode = .eur
    var primaryScheduleId: String?
    var projectionStartDate = ""
    var projectionEndDate = ""
    var extraSpentLimitText = ""
    var schedules: [IncomePaySchedule] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

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
            if let settings = deps.settings {
                language = settings.language
                displayCurrency = settings.displayCurrency
                primaryScheduleId = settings.primaryScheduleId
                projectionStartDate = settings.projectionStartDate ?? ""
                projectionEndDate = settings.projectionEndDate ?? ""
                extraSpentLimitText = settings.extraSpentLimit.map {
                    MoneyFormatter.formatMinorUnitsAsInput($0, currency: settings.displayCurrency)
                } ?? ""
            }
            schedules = try await deps.dataStore.getSchedules { [deps] in
                try await deps.api.getIncomeSchedules()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // The projection's opening balance is the sum of account initial amounts (see the Accounts
        // tab); the legacy projection_initial_free_money setting has been removed entirely.
        var request = PatchSettingsRequest(
            displayCurrency: displayCurrency,
            primaryScheduleId: primaryScheduleId
        )
        if projectionStartDate.isEmpty {
            request.clearProjectionStartDate = true
        } else {
            request.projectionStartDate = projectionStartDate
        }
        if projectionEndDate.isEmpty {
            request.clearProjectionEndDate = true
        } else {
            let today = PayPeriodLogic.todayISO()
            guard Self.isValidISODate(projectionEndDate),
                  projectionEndDate >= today,
                  projectionEndDate <= Self.addMonths(today, 24) else {
                errorMessage = L10n.t("projection end date must be between today and two years from today")
                Haptics.warning()
                return false
            }
            if !projectionStartDate.isEmpty && projectionEndDate < projectionStartDate {
                errorMessage = L10n.t("projection end date cannot precede projection start date")
                Haptics.warning()
                return false
            }
            request.projectionEndDate = projectionEndDate
        }
        request.asOf = PayPeriodLogic.todayISO()

        // Empty input clears the limit; any value must be a positive amount.
        let trimmedLimit = extraSpentLimitText.trimmingCharacters(in: .whitespaces)
        if trimmedLimit.isEmpty {
            request.clearExtraSpentLimit = true
        } else {
            guard let limit = MoneyFormatter.parseToMinorUnits(trimmedLimit, currency: displayCurrency),
                  limit > 0 else {
                errorMessage = L10n.t("invalid extra spent limit")
                Haptics.warning()
                return false
            }
            request.extraSpentLimit = limit
        }

        do {
            _ = try await deps.api.patchSettings(request)
            deps.invalidateAfter(.settingsChange)
            try await deps.refreshSharedContext(force: true)
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.warning()
            return false
        }
    }

    func updateLanguage(_ language: AppLanguage) async -> Bool {
        do {
            _ = try await deps.api.patchSettings(PatchSettingsRequest(language: language))
            deps.invalidateAfter(.settingsChange)
            try await deps.refreshSharedContext(force: true)
            self.language = language
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.warning()
            return false
        }
    }

    func updateTheme(_ theme: String) async -> Bool {
        do {
            _ = try await deps.api.patchSettings(PatchSettingsRequest(theme: theme))
            deps.invalidateAfter(.settingsChange)
            try await deps.refreshSharedContext(force: true)
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.warning()
            return false
        }
    }

    func clearWidgetSnapshot() {
        deps.clearWidgetSnapshot()
    }

    private static func isValidISODate(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: value) != nil
    }

    private static func addMonths(_ value: String, _ months: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: value)!
        let result = formatter.calendar.date(byAdding: .month, value: months, to: date)!
        return formatter.string(from: result)
    }
}
