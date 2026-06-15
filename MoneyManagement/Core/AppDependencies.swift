import Foundation
import Observation

@Observable
@MainActor
final class AppDependencies {
    let sessionStore: SessionStore
    let languageManager: LanguageManager
    let api: APIService
    let dataStore: DataStore

    var settings: UserSettings? {
        dataStore.settings
    }

    var moneyContext: MoneyContextResponse? {
        dataStore.moneyContext
    }

    private(set) var isLoadingContext = false

    /// Last `cacheRevision` observed from `/settings`. Used to skip a full invalidate+reload on
    /// foreground when server-side data is unchanged.
    private(set) var lastSeenCacheRevision: Int?

    var displayCurrency: CurrencyCode {
        dataStore.moneyContext?.displayCurrency
            ?? dataStore.settings?.displayCurrency
            ?? .eur
    }

    var rates: ExchangeRates? {
        dataStore.moneyContext?.rates
    }

    var isAuthenticated: Bool {
        sessionStore.isAuthenticated
    }

    private var widgetLanguage: String {
        languageManager.language.rawValue
    }

    init(sessionStore: SessionStore, languageManager: LanguageManager) {
        self.sessionStore = sessionStore
        self.languageManager = languageManager
        self.dataStore = DataStore()
        let client = APIClient(
            tokenProvider: { [weak sessionStore] in
                guard let token = sessionStore?.session?.accessToken else {
                    throw APIError(status: 401, message: "Not authenticated")
                }
                return token
            },
            onUnauthorized: { [weak sessionStore] in
                try? await sessionStore?.signOut()
            }
        )
        self.api = APIService(client: client)
    }

    func invalidateAfter(_ event: InvalidationEvent) {
        dataStore.invalidateAfter(event)
        if shouldSyncWidgets(for: event) {
            Task { await syncWidgets() }
        }
    }

    func invalidateAll() {
        dataStore.invalidateAll()
    }

    func refreshSharedContext(force: Bool = false) async throws {
        if force {
            dataStore.invalidate([.settings, .moneyContext])
        }

        isLoadingContext = true
        defer { isLoadingContext = false }

        async let settingsTask = dataStore.getSettings { [api] in
            try await api.getSettings()
        }
        async let moneyTask = dataStore.getMoneyContext { [api] in
            try await api.getMoneyContext()
        }
        _ = try await settingsTask
        _ = try await moneyTask
        if let language = dataStore.settings?.language {
            languageManager.apply(language)
        }
        lastSeenCacheRevision = dataStore.settings?.cacheRevision
    }

    /// Called when the app returns to the foreground. Fetches the authoritative `/settings`
    /// `cacheRevision`; only invalidates the in-memory caches when it changed (mirrors the web
    /// app relying on TanStack Query's revision-keyed cache). Returns `true` when the caller
    /// should reload the active tab. On error, invalidates conservatively to avoid stale data.
    func syncOnForeground() async -> Bool {
        do {
            let settings = try await api.getSettings()
            let changed = lastSeenCacheRevision != settings.cacheRevision
            lastSeenCacheRevision = settings.cacheRevision
            if changed {
                dataStore.invalidateAll()
                languageManager.apply(settings.language)
            }
            return changed
        } catch {
            dataStore.invalidateAll()
            return true
        }
    }

    func formatMoney(_ amount: Int, currency: CurrencyCode) -> String {
        MoneyFormatter.format(amount, currency: currency, displayCurrency: displayCurrency, rates: rates)
    }

    func syncWidgets() async {
        await WidgetSyncService.sync(deps: self, language: widgetLanguage)
    }

    func clearWidgetSnapshot() {
        WidgetSyncService.clear(language: widgetLanguage)
    }

    private func shouldSyncWidgets(for event: InvalidationEvent) -> Bool {
        switch event {
        case .expenseChange, .recurringChange, .plannedChange, .budgetChange, .settingsChange, .scheduleChange:
            return true
        case .incomeChange, .moneyContextRefresh:
            return false
        }
    }
}
