import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    private let deps: AppDependencies

    var displayCurrency: CurrencyCode = .eur
    var primaryScheduleId: String?
    var projectionInitialFreeMoneyText = "0"
    var projectionStartDate = ""
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
                displayCurrency = settings.displayCurrency
                primaryScheduleId = settings.primaryScheduleId
                projectionInitialFreeMoneyText = String(settings.projectionInitialFreeMoney)
                projectionStartDate = settings.projectionStartDate ?? ""
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

        let freeMoney = Int(projectionInitialFreeMoneyText) ?? 0
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
}
