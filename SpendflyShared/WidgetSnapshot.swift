import Foundation

public struct WidgetSnapshot: Codable, Sendable {
    public var updatedAt: Date
    public var displayCurrency: CurrencyCode
    public var language: String
    /// Selected theme palette code (e.g. "terminal"). Decoded defensively for older snapshots.
    public var theme: String
    /// App appearance mode: "dark", "light", or "system" (system falls back to the widget's
    /// environment color scheme).
    public var themeMode: String
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
        theme: String = "terminal",
        themeMode: String = "dark",
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
        self.theme = theme
        self.themeMode = themeMode
        self.monthSpent = monthSpent
        self.monthPeriodLabel = monthPeriodLabel
        self.extraSpent = extraSpent
        self.extraSpentLimit = extraSpentLimit
        self.payPeriodLabel = payPeriodLabel
        self.hasPrimarySchedule = hasPrimarySchedule
        self.isSignedIn = isSignedIn
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        displayCurrency = try c.decode(CurrencyCode.self, forKey: .displayCurrency)
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? "en"
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? "terminal"
        themeMode = try c.decodeIfPresent(String.self, forKey: .themeMode) ?? "dark"
        monthSpent = try c.decode(Int.self, forKey: .monthSpent)
        monthPeriodLabel = try c.decode(String.self, forKey: .monthPeriodLabel)
        extraSpent = try c.decode(Int.self, forKey: .extraSpent)
        extraSpentLimit = try c.decodeIfPresent(Int.self, forKey: .extraSpentLimit)
        payPeriodLabel = try c.decodeIfPresent(String.self, forKey: .payPeriodLabel)
        hasPrimarySchedule = try c.decode(Bool.self, forKey: .hasPrimarySchedule)
        isSignedIn = try c.decode(Bool.self, forKey: .isSignedIn)
    }

    public static func signedOut(
        language: String = "en",
        theme: String = "terminal",
        themeMode: String = "dark"
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            displayCurrency: .eur,
            language: language,
            theme: theme,
            themeMode: themeMode,
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
