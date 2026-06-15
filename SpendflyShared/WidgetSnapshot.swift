import Foundation

public struct WidgetSnapshot: Codable, Sendable {
    public var updatedAt: Date
    public var displayCurrency: CurrencyCode
    public var language: String
    public var monthSpent: Int
    public var monthPeriodLabel: String
    public var extraSpent: Int
    public var extraSpentLimit: Int?
    public var payPeriodLabel: String?
    /// When false, the pay-period extra-spent widget shows a setup prompt.
    public var hasPrimarySchedule: Bool
    public var isSignedIn: Bool

    public init(
        updatedAt: Date = Date(),
        displayCurrency: CurrencyCode,
        language: String = "en",
        monthSpent: Int,
        monthPeriodLabel: String,
        extraSpent: Int,
        extraSpentLimit: Int?,
        payPeriodLabel: String?,
        hasPrimarySchedule: Bool,
        isSignedIn: Bool
    ) {
        self.updatedAt = updatedAt
        self.displayCurrency = displayCurrency
        self.language = language
        self.monthSpent = monthSpent
        self.monthPeriodLabel = monthPeriodLabel
        self.extraSpent = extraSpent
        self.extraSpentLimit = extraSpentLimit
        self.payPeriodLabel = payPeriodLabel
        self.hasPrimarySchedule = hasPrimarySchedule
        self.isSignedIn = isSignedIn
    }

    public static func signedOut(language: String = "en") -> WidgetSnapshot {
        WidgetSnapshot(
            displayCurrency: .eur,
            language: language,
            monthSpent: 0,
            monthPeriodLabel: "",
            extraSpent: 0,
            extraSpentLimit: nil,
            payPeriodLabel: nil,
            hasPrimarySchedule: false,
            isSignedIn: false
        )
    }
}
