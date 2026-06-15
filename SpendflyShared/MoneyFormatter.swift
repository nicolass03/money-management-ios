import Foundation

public enum SharedMoneyFormatter {
    private static let locales: [CurrencyCode: String] = [
        .usd: "en_US",
        .eur: "de_DE",
        .cop: "es_CO",
    ]

    private static func minorDivisor(for currency: CurrencyCode) -> Int {
        currency == .cop ? 1 : 100
    }

    public static func format(_ amountMinor: Int, currency: CurrencyCode) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: locales[currency] ?? "en_US")
        formatter.currencyCode = currency.rawValue.uppercased()
        formatter.minimumFractionDigits = currency == .cop ? 0 : 2
        formatter.maximumFractionDigits = currency == .cop ? 0 : 2

        let divisor = Double(minorDivisor(for: currency))
        return formatter.string(from: NSNumber(value: Double(amountMinor) / divisor)) ?? "\(amountMinor)"
    }
}
