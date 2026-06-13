import Foundation
import Observation

@Observable
@MainActor
final class AppDependencies {
    let sessionStore: SessionStore
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

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
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

        // Seed the in-memory cache from disk so the first paint shows last-known data instead of a
        // skeleton; the tab loads then revalidate in the background (stale-while-revalidate).
        if let userID = sessionStore.session?.user.id.uuidString {
            dataStore.hydrate(userID: userID)
        }
    }

    func invalidateAfter(_ event: InvalidationEvent) {
        dataStore.invalidateAfter(event)
    }

    func invalidateAll() {
        dataStore.invalidateAll()
    }

    func refreshSharedContext(force: Bool = false) async throws {
        if force {
            dataStore.invalidate([.settings, .moneyContext])
        }

        // Only surface the context skeleton when there's nothing cached to show; with hydrated
        // settings + money-context the refresh happens silently in the background.
        isLoadingContext = (dataStore.settings == nil || dataStore.moneyContext == nil)
        defer { isLoadingContext = false }

        async let settingsTask = dataStore.getSettings { [api] in
            try await api.getSettings()
        }
        async let moneyTask = dataStore.getMoneyContext { [api] in
            try await api.getMoneyContext()
        }
        _ = try await settingsTask
        _ = try await moneyTask
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
}
