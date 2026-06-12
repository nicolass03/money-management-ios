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
    }

    func formatMoney(_ amount: Int, currency: CurrencyCode) -> String {
        MoneyFormatter.format(amount, currency: currency, displayCurrency: displayCurrency, rates: rates)
    }
}
