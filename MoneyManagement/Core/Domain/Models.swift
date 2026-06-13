import Foundation

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
        case .weekly: "weekly"
        case .biweekly: "every 2 weeks"
        case .monthly: "monthly"
        case .yearly: "yearly"
        }
    }
}

enum IncomeSource: String, Codable {
    case scheduled, manual
}

struct UserSettings: Codable, Equatable {
    let id: String
    let displayCurrency: CurrencyCode
    let primaryScheduleId: String?
    let primarySchedule: IncomePaySchedule?
    let projectionInitialFreeMoney: Int
    let projectionStartDate: String?
    let cacheRevision: Int
    let updatedAt: String
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
    var primaryScheduleId: String?
    var clearPrimarySchedule = false
    var projectionInitialFreeMoney: Int?
    var projectionStartDate: String?
    var clearProjectionStartDate = false

    enum CodingKeys: String, CodingKey {
        case displayCurrency, primaryScheduleId
        case projectionInitialFreeMoney, projectionStartDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let displayCurrency {
            try container.encode(displayCurrency, forKey: .displayCurrency)
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
        case .lastPeriod: "last period"
        case .lastMonth: "last month"
        case .last3Months: "last 3 months"
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
