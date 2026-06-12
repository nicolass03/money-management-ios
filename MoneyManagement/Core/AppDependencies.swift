import Foundation
import Observation

@Observable
@MainActor
final class AppDependencies {
    let sessionStore: SessionStore
    let api: APIService

    private(set) var settings: UserSettings?
    private(set) var moneyContext: MoneyContextResponse?
    private(set) var isLoadingContext = false

    var displayCurrency: CurrencyCode {
        moneyContext?.displayCurrency ?? settings?.displayCurrency ?? .eur
    }

    var rates: ExchangeRates? {
        moneyContext?.rates
    }

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
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

    func refreshSharedContext() async throws {
        isLoadingContext = true
        defer { isLoadingContext = false }

        async let settingsTask = api.getSettings()
        async let moneyTask = api.getMoneyContext()
        settings = try await settingsTask
        moneyContext = try await moneyTask
    }

    func formatMoney(_ amount: Int, currency: CurrencyCode) -> String {
        MoneyFormatter.format(amount, currency: currency, displayCurrency: displayCurrency, rates: rates)
    }
}
