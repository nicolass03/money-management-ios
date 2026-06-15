import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    private let deps: AppDependencies

    var language: AppLanguage = .en
    var displayCurrency: CurrencyCode = .eur
    var primaryScheduleId: String?
    var projectionInitialFreeMoneyText = "0"
    var projectionStartDate = ""
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
                projectionInitialFreeMoneyText = MoneyFormatter.formatMinorUnitsAsInput(
                    settings.projectionInitialFreeMoney,
                    currency: settings.displayCurrency
                )
                projectionStartDate = settings.projectionStartDate ?? ""
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

        guard let freeMoney = MoneyFormatter.parseSignedToMinorUnits(
            projectionInitialFreeMoneyText,
            currency: displayCurrency
        ) else {
            errorMessage = L10n.t("invalid initial free money amount")
            Haptics.warning()
            return false
        }
        var request = PatchSettingsRequest(
            displayCurrency: displayCurrency,
            primaryScheduleId: primaryScheduleId,
            projectionInitialFreeMoney: freeMoney
        )
        if projectionStartDate.isEmpty {
            request.clearProjectionStartDate = true
        } else {
            request.projectionStartDate = projectionStartDate
        }

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

    func clearWidgetSnapshot() {
        deps.clearWidgetSnapshot()
    }
}
