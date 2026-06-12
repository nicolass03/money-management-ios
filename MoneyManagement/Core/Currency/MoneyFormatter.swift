import Foundation

enum CurrencyConverter {
    static func minorDivisor(for currency: CurrencyCode) -> Int {
        currency == .cop ? 1 : 100
    }

    static func convert(
        amountMinor: Int,
        from: CurrencyCode,
        to: CurrencyCode,
        rates: ExchangeRates
    ) -> Int {
        if from == to { return amountMinor }

        let fromRate = rates.rates[from.rawValue.uppercased()]
        let toRate = rates.rates[to.rawValue.uppercased()]
        guard let fromRate, let toRate, fromRate > 0 else { return amountMinor }

        let majorInUsd = Double(amountMinor) / Double(minorDivisor(for: from)) / fromRate
        let majorInTarget = majorInUsd * toRate
        return Int((majorInTarget * Double(minorDivisor(for: to))).rounded())
    }
}

enum MoneyFormatter {
    private static let locales: [CurrencyCode: String] = [
        .usd: "en_US",
        .eur: "de_DE",
        .cop: "es_CO"
    ]

    static func format(
        _ amountMinor: Int,
        currency: CurrencyCode,
        displayCurrency: CurrencyCode? = nil,
        rates: ExchangeRates? = nil
    ) -> String {
        let target = displayCurrency ?? currency
        let converted: Int
        if let rates, currency != target {
            converted = CurrencyConverter.convert(amountMinor: amountMinor, from: currency, to: target, rates: rates)
        } else {
            converted = amountMinor
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: locales[target] ?? "en_US")
        formatter.currencyCode = target.rawValue.uppercased()
        formatter.minimumFractionDigits = target == .cop ? 0 : 2
        formatter.maximumFractionDigits = target == .cop ? 0 : 2

        let divisor = Double(CurrencyConverter.minorDivisor(for: target))
        return formatter.string(from: NSNumber(value: Double(converted) / divisor)) ?? "\(converted)"
    }

    static func formatSigned(
        _ amountMinor: Int,
        currency: CurrencyCode,
        displayCurrency: CurrencyCode? = nil,
        rates: ExchangeRates? = nil,
        sign: String = "+"
    ) -> String {
        "\(sign)\(format(amountMinor, currency: currency, displayCurrency: displayCurrency, rates: rates))"
    }

    static func parseToMinorUnits(_ text: String, currency: CurrencyCode) -> Int? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
            .filter { "0123456789.-".contains($0) }
        guard let value = Double(cleaned) else { return nil }
        return Int((value * Double(CurrencyConverter.minorDivisor(for: currency))).rounded())
    }
}
