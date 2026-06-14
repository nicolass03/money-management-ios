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

  /// Decimal input for forms — parity with web `formatCentsAsDollarsInput`.
  static func formatMinorUnitsAsInput(_ amountMinor: Int, currency: CurrencyCode) -> String {
    let major = Double(amountMinor) / Double(CurrencyConverter.minorDivisor(for: currency))
    if currency == .cop {
      return String(Int(major.rounded()))
    }
    return String(format: "%.2f", major)
  }

  static func parseToMinorUnits(_ text: String, currency: CurrencyCode) -> Int? {
    parseSignedToMinorUnits(text, currency: currency).flatMap { $0 >= 0 ? $0 : nil }
  }

  /// Parity with web `parseSignedDollarsToCents` (settings projection balance).
  static func parseSignedToMinorUnits(_ text: String, currency: CurrencyCode) -> Int? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return 0 }

    guard let normalized = normalizeAmountInput(trimmed) else { return nil }
    guard let value = Double(normalized), value.isFinite else { return nil }
    return Int((value * Double(CurrencyConverter.minorDivisor(for: currency))).rounded())
  }

  private static func normalizeAmountInput(_ text: String) -> String? {
    var value = text
      .replacingOccurrences(of: "$", with: "")
      .replacingOccurrences(of: "€", with: "")
      .replacingOccurrences(of: " ", with: "")

    var sign = ""
    if value.first == "-" {
      sign = "-"
      value.removeFirst()
    }

    guard !value.isEmpty else { return nil }

    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count <= 2 else { return nil }

    let integerPart = String(parts[0])
    let fractionPart = parts.count == 2 ? String(parts[1]) : nil
    guard isValidIntegerPart(integerPart), isValidFractionPart(fractionPart) else { return nil }
    guard integerPart.contains(where: \.isNumber) || fractionPart?.contains(where: \.isNumber) == true else { return nil }

    let normalizedInteger = integerPart.replacingOccurrences(of: ",", with: "")
    return sign + normalizedInteger + (fractionPart.map { ".\($0)" } ?? "")
  }

  private static func isValidIntegerPart(_ value: String) -> Bool {
    if value.isEmpty { return true }

    if value.contains(",") {
      let groups = value.split(separator: ",", omittingEmptySubsequences: false)
      guard let first = groups.first, (1...3).contains(first.count), first.allSatisfy(\.isNumber) else {
        return false
      }
      return groups.dropFirst().allSatisfy { $0.count == 3 && $0.allSatisfy(\.isNumber) }
    }

    return value.allSatisfy(\.isNumber)
  }

  private static func isValidFractionPart(_ value: String?) -> Bool {
    guard let value else { return true }
    return value.count <= 2 && value.allSatisfy(\.isNumber)
  }
}
