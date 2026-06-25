import Foundation
import Observation

@Observable
@MainActor
final class AppDependencies {
    let sessionStore: SessionStore
    let languageManager: LanguageManager
    let themeManager: ThemeManager
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

    private var widgetTheme: String {
        dataStore.settings?.theme ?? themeManager.themeCode
    }

    private var widgetThemeMode: String {
        themeManager.mode.rawValue
    }

    init(sessionStore: SessionStore, languageManager: LanguageManager, themeManager: ThemeManager) {
        self.sessionStore = sessionStore
        self.languageManager = languageManager
        self.themeManager = themeManager
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
            // Theme is applied independently of the cache-revision gate so a theme change made on
            // another device (which still bumps cacheRevision) is reflected here, and so a no-op
            // reload keeps the local selection aligned with the server.
            themeManager.setTheme(settings.theme)
            return changed
        } catch {
            dataStore.invalidateAll()
            return true
        }
    }

    /// Re-derives on-device cancellation reminders from the latest recurring expenses. Called on
    /// launch, on foreground (when data changed), and after a reminder is toggled.
    func refreshSubscriptionReminders() async {
        guard
            let recurring = try? await dataStore.getRecurringExpenses(fetch: { [api] in
                try await api.getRecurringExpenses()
            })
        else {
            return
        }
        await SubscriptionReminderScheduler.reschedule(from: recurring)
    }

    func formatMoney(_ amount: Int, currency: CurrencyCode) -> String {
        MoneyFormatter.format(amount, currency: currency, displayCurrency: displayCurrency, rates: rates)
    }

    func syncWidgets() async {
        await WidgetSyncService.sync(
            deps: self,
            language: widgetLanguage,
            theme: widgetTheme,
            themeMode: widgetThemeMode
        )
    }

    func clearWidgetSnapshot() {
        WidgetSyncService.clear(
            language: widgetLanguage,
            theme: widgetTheme,
            themeMode: widgetThemeMode
        )
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
