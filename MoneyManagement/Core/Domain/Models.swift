import Foundation
import SpendflyShared

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case en, es

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .en: "en"
        case .es: "es"
        }
    }
}

enum CurrencyCode: String, Codable, CaseIterable, Identifiable {
    case eur, usd, cop

    var id: String { rawValue }

    var label: String { rawValue.uppercased() }
}

enum PayFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly, biweekly, monthly, yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: L10n.t("weekly")
        case .biweekly: L10n.t("every 2 weeks")
        case .monthly: L10n.t("monthly")
        case .yearly: L10n.t("yearly")
        }
    }
}

enum IncomeSource: String, Codable {
    case scheduled, manual

    var label: String {
        switch self {
        case .scheduled: L10n.t("scheduled")
        case .manual: L10n.t("manual")
        }
    }
}

struct UserSettings: Codable, Equatable {
    let id: String
    let displayCurrency: CurrencyCode
    let language: AppLanguage
    let primaryScheduleId: String?
    let primarySchedule: IncomePaySchedule?
    let projectionInitialFreeMoney: Int
    let projectionStartDate: String?
    let extraSpentLimit: Int?
    let theme: String
    let cacheRevision: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, displayCurrency, language, primaryScheduleId, primarySchedule
        case projectionInitialFreeMoney, projectionStartDate, extraSpentLimit
        case theme, cacheRevision, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayCurrency = try container.decode(CurrencyCode.self, forKey: .displayCurrency)
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .en
        primaryScheduleId = try container.decodeIfPresent(String.self, forKey: .primaryScheduleId)
        primarySchedule = try container.decodeIfPresent(IncomePaySchedule.self, forKey: .primarySchedule)
        projectionInitialFreeMoney = try container.decode(Int.self, forKey: .projectionInitialFreeMoney)
        projectionStartDate = try container.decodeIfPresent(String.self, forKey: .projectionStartDate)
        extraSpentLimit = try container.decodeIfPresent(Int.self, forKey: .extraSpentLimit)
        theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? SpendflyThemes.defaultCode
        cacheRevision = try container.decode(Int.self, forKey: .cacheRevision)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
}

struct IncomePaySchedule: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let anchorDate: String
    let frequency: PayFrequency
    let amount: Int
    let currency: CurrencyCode
    let createdAt: String
    let updatedAt: String
}

struct Income: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Int
    let currency: CurrencyCode
    let source: IncomeSource
    let date: String
    let scheduleId: String?
    let createdAt: String

    var isManual: Bool { source == .manual && scheduleId == nil }
}

struct Expense: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Int
    let currency: CurrencyCode
    let date: String
    let scheduledDate: String?
    let recurringId: String?
    let plannedExpenseId: String?
    let budgetId: String?
    let amountOverridden: Bool
    let isSubscription: Bool
    let createdAt: String

    var isSystemGenerated: Bool { recurringId != nil || plannedExpenseId != nil || budgetId != nil }
}

struct ExpenseWithTags: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Int
    let currency: CurrencyCode
    let date: String
    let scheduledDate: String?
    let recurringId: String?
    let plannedExpenseId: String?
    let budgetId: String?
    let amountOverridden: Bool
    let isSubscription: Bool
    let createdAt: String
    let tags: [String]

    var isSystemGenerated: Bool { recurringId != nil || plannedExpenseId != nil || budgetId != nil }
}

struct RecurringExpenseWithTags: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let anchorDate: String
    let frequency: PayFrequency
    let amount: Int
    let currency: CurrencyCode
    let isSubscription: Bool
    let lastPaymentDate: String?
    let createdAt: String
    let updatedAt: String
    let tags: [String]
    let cancelReminderEnabled: Bool
}

struct PlannedExpenseWithTags: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let date: String
    let amount: Int
    let currency: CurrencyCode
    let createdAt: String
    let updatedAt: String
    let tags: [String]
}

struct BudgetWithTags: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Int
    let currency: CurrencyCode
    let startDate: String?
    let endDate: String?
    let createdAt: String
    let updatedAt: String
    let tags: [String]
    let spent: Int
}

struct ExchangeRates: Codable, Equatable {
    let base: String
    let rates: [String: Double]
    let fetchedAt: String
}

struct MoneyContextResponse: Codable, Equatable {
    let displayCurrency: CurrencyCode
    let rates: ExchangeRates
}

struct ProjectionExpenseItem: Codable, Identifiable, Equatable {
    var id: String { itemId ?? "\(name)-\(date)-\(amount)" }
    let itemId: String?
    let recurringId: String?
    let plannedExpenseId: String?
    let budgetId: String?
    let budgetTotal: Int?
    let budgetSpent: Int?
    let isBudgetSummary: Bool?
    let name: String
    let date: String
    let scheduledDate: String?
    let amount: Int
    let currency: CurrencyCode
    let originalAmount: Int?
    let originalCurrency: CurrencyCode?
    let convertedAmount: Int
    let tags: [String]
    let isSubscription: Bool
    let projected: Bool

    enum CodingKeys: String, CodingKey {
        case itemId = "id"
        case recurringId, plannedExpenseId, budgetId
        case budgetTotal, budgetSpent, isBudgetSummary
        case name, date, scheduledDate, amount, currency
        case originalAmount, originalCurrency, convertedAmount
        case tags, isSubscription, projected
    }
}

struct ProjectionRow: Codable, Identifiable, Equatable {
    var id: String { payDate }
    let payDate: String
    let startDate: String
    let endDate: String
    let incomeTotal: Int
    let expenseTotal: Int
    let periodFree: Int
    let cumulativeFree: Int
    let expenseItems: [ProjectionExpenseItem]
    let isPast: Bool
}

struct ProjectionsResponse: Codable, Equatable {
    let rows: [ProjectionRow]
    let primarySchedule: IncomePaySchedule
    let displayCurrency: CurrencyCode
    let rates: ExchangeRates
}

struct SuccessResponse: Codable {
    let success: Bool
}

struct ErrorResponse: Codable {
    let error: String
}

// MARK: - Request bodies

struct PatchSettingsRequest: Encodable {
    var displayCurrency: CurrencyCode?
    var language: AppLanguage?
    var primaryScheduleId: String?
    var clearPrimarySchedule = false
    var projectionInitialFreeMoney: Int?
    var projectionStartDate: String?
    var clearProjectionStartDate = false
    var extraSpentLimit: Int?
    var clearExtraSpentLimit = false
    var theme: String?

    enum CodingKeys: String, CodingKey {
        case displayCurrency, language, primaryScheduleId
        case projectionInitialFreeMoney, projectionStartDate
        case extraSpentLimit, theme
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let displayCurrency {
            try container.encode(displayCurrency, forKey: .displayCurrency)
        }
        if let language {
            try container.encode(language, forKey: .language)
        }
        if clearPrimarySchedule {
            try container.encodeNil(forKey: .primaryScheduleId)
        } else if let primaryScheduleId {
            try container.encode(primaryScheduleId, forKey: .primaryScheduleId)
        }
        if let projectionInitialFreeMoney {
            try container.encode(projectionInitialFreeMoney, forKey: .projectionInitialFreeMoney)
        }
        if clearProjectionStartDate {
            try container.encodeNil(forKey: .projectionStartDate)
        } else if let projectionStartDate {
            try container.encode(projectionStartDate, forKey: .projectionStartDate)
        }
        if clearExtraSpentLimit {
            try container.encodeNil(forKey: .extraSpentLimit)
        } else if let extraSpentLimit {
            try container.encode(extraSpentLimit, forKey: .extraSpentLimit)
        }
        if let theme {
            try container.encode(theme, forKey: .theme)
        }
    }
}

struct CreateIncomeScheduleRequest: Encodable {
    let name: String
    let anchorDate: String
    let frequency: PayFrequency
    let amount: Int
    let currency: CurrencyCode
}

struct CreateIncomeRequest: Encodable {
    let name: String
    let amount: Int
    let currency: CurrencyCode
    let date: String
}

struct CreateExpenseRequest: Encodable {
    let name: String
    let amount: Int
    let currency: CurrencyCode
    let date: String
    let tags: [String]
    let isSubscription: Bool
}

struct UpdateExpenseAmountRequest: Encodable {
    let amount: Int
}

struct EarlyPayExpenseRequest: Encodable {
    let sourceType: String
    let scheduledDate: String
    let paidDate: String
    let amount: Int
    let currency: CurrencyCode
    let recurringId: String?
    let plannedExpenseId: String?
}

struct CreateRecurringExpenseRequest: Encodable {
    let name: String
    let anchorDate: String
    let frequency: PayFrequency
    let amount: Int
    let currency: CurrencyCode
    let tags: [String]
    let isSubscription: Bool
    let lastPaymentDate: String?
}

struct CreatePlannedExpenseRequest: Encodable {
    let name: String
    let date: String
    let amount: Int
    let currency: CurrencyCode
    let tags: [String]
}

struct CreateBudgetRequest: Encodable {
    let name: String
    let amount: Int
    let currency: CurrencyCode
    let startDate: String?
    let endDate: String?
    let tags: [String]
}

struct CreateBudgetExpenseRequest: Encodable {
    let name: String?
    let amount: Int
    let date: String
}

enum ExpensePeriodKey: String, CaseIterable, Identifiable {
    case lastPeriod = "last-period"
    case lastMonth = "last-month"
    case last3Months = "last-3-months"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lastPeriod: L10n.t("last period")
        case .lastMonth: L10n.t("last month")
        case .last3Months: L10n.t("last 3 months")
        }
    }
}

struct PayPeriod: Equatable {
    let payDate: String
    let startDate: String
    let endDate: String
}

struct PayableFutureItem: Identifiable, Equatable, Codable {
    let key: String
    let sourceType: String
    let recurringId: String?
    let plannedExpenseId: String?
    let scheduledDate: String
    let name: String
    let amount: Int
    let currency: CurrencyCode
    let tags: [String]
    let isSubscription: Bool

    var id: String { key }
}

struct ExpensePeriodViewResponse: Codable, Equatable {
    let period: PayPeriodResponse
    let items: [ProjectionExpenseItem]
    let totalSpend: Int
    let isPayPeriod: Bool
    // Actual unplanned spend in the period (expenses not tied to recurring/planned/budget),
    // converted to the display currency. extraSpentLimit is only surfaced for the pay period.
    // Optional so the client still decodes responses from an API that predates this field.
    let extraSpent: Int?
    let extraSpentLimit: Int?
}

struct PayPeriodResponse: Codable, Equatable {
    let payDate: String
    let startDate: String
    let endDate: String
}

/// Default horizon (days) for the upcoming-payable query. Shared so the request, the cache
/// key, and `InvalidationMap` can never drift apart.
enum ExpenseDefaults {
    static let upcomingPayableHorizonDays = 30
}
